package Perl::CodeMap;
use strict;
use warnings;
use 5.020;
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use File::Find ();
use File::Spec ();
use JSON::PP ();
use Encode qw(decode FB_DEFAULT);
use IPC::Open3 ();
use Symbol qw(gensym);

our $VERSION = '0.3.0';

sub new {
    my ($class, %arg) = @_;
    my $root = abs_path($arg{root} // '.');
    die "Source directory does not exist\n" unless defined $root && -d $root;
    my $mode = $arg{parser} // 'auto';
    die "parser must be one of auto, ppi, lite\n" unless $mode =~ /\A(?:auto|ppi|lite)\z/;
    my $ppi = eval { require PPI; 1 } ? 1 : 0;
    die "PPI is not installed. Install it using 'cpanm PPI', or use --parser lite\n"
        if $mode eq 'ppi' && !$ppi;
    my $selected = $mode eq 'auto' ? ($ppi ? 'ppi' : 'lite') : $mode;
    my $max_bytes = $arg{max_source_bytes} // 2_000_000;
    die "max_source_bytes must be a positive integer\n" unless $max_bytes =~ /\A[1-9][0-9]*\z/;
    return bless {
        root => $root, parser => $selected,
        include_tests => $arg{include_tests} ? 1 : 0,
        embed_source => exists $arg{embed_source} ? ($arg{embed_source} ? 1 : 0) : 1,
        max_source_bytes => $max_bytes,
        source_base => $arg{source_base}, name => $arg{name},
        warnings => [],
    }, $class;
}

sub analyze {
    my ($self) = @_;
    my $root = $self->{root};
    my %ignored = map { $_ => 1 } qw(.git .svn .hg .idea .vscode node_modules vendor blib local _build cover_db .cache);
    if (!$self->{include_tests}) { $ignored{$_} = 1 for qw(t xt tests test); }
    my @candidates;
    File::Find::find({ no_chdir => 1, follow => 0, wanted => sub {
        my $path = $File::Find::name;
        if (-d $path) {
            my $base = basename($path);
            $File::Find::prune = 1 if $path ne $root && ($ignored{$base} || $base =~ /^\./);
            return;
        }
        return unless -f $path && !-l $path;
        return unless $self->{include_tests} || $path !~ /\.t\z/;
        return unless $path =~ /\.(?:pm|pl|psgi|t)\z/i || basename($path) !~ /\./;
        push @candidates, $path;
    } }, $root);
    @candidates = sort @candidates;
    my (%packages, %sources, $file_count);
    $file_count = 0;
    for my $path (@candidates) {
        open my $fh, '<:raw', $path or do {
            push @{$self->{warnings}}, 'Unable to read ' . File::Spec->abs2rel($path, $root);
            next;
        };
        local $/;
        my $raw = <$fh>;
        close $fh;
        my $rel = File::Spec->abs2rel($path, $root);
        $rel =~ s{\\}{/}g;
        next if $rel !~ /\.(?:pm|pl|psgi|t)\z/i && $raw !~ /\A\#![^\n]*\bperl\b/;
        $file_count++;
        if ($self->{embed_source}) {
            if (length($raw) <= $self->{max_source_bytes}) {
                $sources{$rel} = decode('UTF-8', $raw, FB_DEFAULT);
            } else {
                push @{$self->{warnings}}, "Source exceeds embedding limit: $rel";
            }
        }
        my $parsed = $self->_parse_file($path, $rel, $raw);
        my %associated;
        for my $event (@{$parsed->{events}}) {
            my $pkg = $event->{type} eq 'package' ? $event->{name}
                : _package_at($parsed->{scopes}, $event->{line}, $parsed->{default});
            next unless defined $pkg && $pkg =~ /\A[A-Za-z_]\w*(?:::\w+)*\z/;
            $associated{$pkg} = 1;
            my $p = $packages{$pkg} ||= {path => $pkg, dir => dirname($rel), doc => '', imports => {}, files => {}};
            my $f = $p->{files}{$rel} ||= {path => $rel, name => basename($rel), lines => $parsed->{lines}, funcs => []};
            if ($event->{type} eq 'package') {
                $p->{doc} ||= _preceding_comment($parsed->{raw_lines}, $event->{line});
            } elsif ($event->{type} eq 'sub') {
                push @{$f->{funcs}}, {
                    n => $event->{name}, l => $event->{line}, s => $event->{size},
                    k => $event->{kind}, e => ($event->{name} !~ /^_/ ? JSON::PP::true : JSON::PP::false),
                    d => _preceding_comment($parsed->{raw_lines}, $event->{line}),
                };
            } elsif ($event->{type} eq 'include') {
                for my $target (@{$event->{targets}}) {
                    $p->{imports}{$target} = 1 if $target ne $pkg;
                }
            }
        }
        if (!%associated) {
            my $pkg = $parsed->{default};
            my $p = $packages{$pkg} ||= {path => $pkg, dir => dirname($rel), doc => '', imports => {}, files => {}};
            $p->{files}{$rel} ||= {path => $rel, name => basename($rel), lines => $parsed->{lines}, funcs => []};
        }
    }
    my @pkgs;
    for my $name (sort keys %packages) {
        my $p = $packages{$name};
        my @files = sort { $a->{path} cmp $b->{path} } values %{$p->{files}};
        for my $file (@files) {
            my %seen;
            @{$file->{funcs}} = sort { $a->{l} <=> $b->{l} || $a->{n} cmp $b->{n} }
                grep { !$seen{join(':', $_->{l}, $_->{n})}++ } @{$file->{funcs}};
        }
        push @pkgs, {
            path => $name, dir => $p->{dir}, doc => $p->{doc}, files => \@files,
            imports => [ sort grep { $_ ne $name && exists $packages{$_} } keys %{$p->{imports}} ],
        };
    }
    my ($source, $rev) = $self->_source_info;
    return {
        format => 1, name => ($self->{name} // basename($root)), module => $root,
        parser => $self->{parser}, rev => $rev, source => $source, scanned_files => $file_count,
        pkgs => \@pkgs, sources => \%sources, warnings => [@{$self->{warnings}}],
    };
}

sub _parse_file {
    my ($self, $path, $rel, $raw) = @_;
    my @lines = split /\n/, $raw, -1;
    pop @lines if @lines > 1 && $lines[-1] eq '';
    my $default = _inferred_name($rel);
    my @events;
    my @scopes;
    my @lite = _mask_lines(\@lines);
    if ($self->{parser} eq 'ppi') {
        my $doc = eval { PPI::Document->new($path) };
        if ($doc) {
            $doc->index_locations;
            for my $p (@{$doc->find('PPI::Statement::Package') || []}) {
                my $name = $p->namespace;
                my $at = $p->location;
                next unless $name && $at;
                my $scope = { name => $name, line => $at->[0] };
                push @scopes, $scope;
                push @events, {type => 'package', name => $name, line => $at->[0]};
            }
            for my $s (@{$doc->find('PPI::Statement::Sub') || []}) {
                my $name = $s->name;
                my $at = $s->location;
                next unless $name && $at;
                my $end = $at->[0];
                my $block = $s->block;
                if ($block) {
                    my $last = $block->last_token;
                    my $finish = $last && $last->location;
                    $end = $finish->[0] if $finish && $finish->[0] > $end;
                }
                push @events, {type => 'sub', name => $name, line => $at->[0],
                    size => $end-$at->[0]+1, kind => 'sub'};
            }
            for my $s (@{$doc->find('PPI::Statement::Include') || []}) {
                next if ($s->type // '') eq 'no';
                my $name = $s->module;
                my $at = $s->location;
                next unless $at && $name && $name =~ /\A[A-Za-z_]\w*(?:::\w+)*\z/;
                push @events, {type => 'include', line => $at->[0], targets => [$name]};
            }
        } else {
            push @{$self->{warnings}}, "PPI could not parse $rel; using limited parser";
            push @events, _lite_events(\@lite, \@lines);
        }
    } else {
        push @events, _lite_events(\@lite, \@lines);
    }
    # Explicit scopes from literal source also support the optional lite mode;
    # this intentionally does not attempt full lexical Perl semantics.
    for my $i (0..$#lite) {
        next unless $lite[$i] =~ /^\s*package\s+([A-Za-z_]\w*(?:::\w+)*)\b/;
        my $name = $1;
        next if $self->{parser} eq 'ppi' && grep { $_->{name} eq $name && $_->{line} == $i+1 } @scopes;
        push @scopes, {name => $name, line => $i+1};
        push @events, {type => 'package', name => $name, line => $i+1};
    }
    push @events, _extra_events(\@lite, \@lines);
    my %seen;
    @events = grep {
        !$seen{join('|', $_->{type}, $_->{line}, ($_->{name}//''), ($_->{kind}//''),
            join(',',@{$_->{targets}//[]}))}++
    } @events;
    @scopes = sort { $a->{line} <=> $b->{line} } @scopes;
    return {events => \@events, scopes => \@scopes, default => $default, lines => scalar(@lines), raw_lines => \@lines};
}

sub _inferred_name {
    my ($rel) = @_;
    if ($rel =~ /(?:^|\/)lib\/(.+)\.pm\z/ || $rel =~ /\A(.+)\.pm\z/) {
        my $name = $1;
        $name =~ s{/}{::}g;
        return $name if $name =~ /\A[A-Za-z_]\w*(?:::\w+)*\z/;
    }
    return 'main';
}

sub _package_at {
    my ($scopes, $line, $default) = @_;
    my $pkg = $default;
    for my $p (@$scopes) {
        last if $p->{line} > $line;
        $pkg = $p->{name};
    }
    return $pkg;
}

sub _mask_lines {
    my ($lines) = @_;
    my @out;
    my $pod = 0;
    my @heredocs;
    my $ended = 0;
    for my $raw (@$lines) {
        if ($ended) { push @out, ""; next; }
        if (@heredocs) {
            push @out, '';
            shift @heredocs if $raw =~ /^\Q$heredocs[0]\E\s*;?\s*\z/;
            next;
        }
        if ($pod) {
            $pod = 0 if $raw =~ /^=cut\b/;
            push @out, '';
            next;
        }
        if ($raw =~ /^=(?:pod|head\d|begin|for|item|over|back|encoding)\b/) {
            $pod = 1; push @out, ''; next;
        }
        if ($raw =~ /^__(?:DATA|END)__\b/) { $ended = 1; push @out, ''; next; }
        my ($out, $quote) = ('','');
        my @chars = split //, $raw;
        for (my $i=0; $i<@chars; $i++) {
            my $char = $chars[$i];
            if ($quote) {
                if ($char eq '\\') { $out .= '  '; $i++ if $i+1<@chars; next; }
                $quote = '' if $char eq $quote;
                $out .= ' '; next;
            }
            last if $char eq '#';
            if ($char eq "'" || $char eq '"' || $char eq '`') {
                $quote = $char; $out .= ' '; next;
            }
            $out .= $char;
        }
        push @out, $out;
        while ($out =~ /<<\s*([A-Za-z_]\w*)/g) { push @heredocs, $1; }
        while ($raw =~ /<<\s*['"]([A-Za-z_]\w*)['"]/g) { push @heredocs, $1; }
    }
    return @out;
}

sub _block_length {
    my ($lines,$start) = @_;
    for my $i ($start..$#$lines) {
        last if $i > $start+30;
        my $offset = index($lines->[$i],'{');
        if ($offset >= 0) {
            my $depth = 0;
            for my $j ($i..$#$lines) {
                my $line = $lines->[$j];
                for(my $c=($j==$i?$offset:0); $c<length($line); $c++) {
                    my $ch = substr($line,$c,1);
                    $depth++ if $ch eq '{';
                    $depth-- if $ch eq '}';
                    return $j-$start+1 if $depth == 0;
                }
            }
            return 1;
        }
        return 1 if $lines->[$i] =~ /;/;
    }
    return 1;
}

sub _lite_events {
    my ($masked,$original) = @_;
    my @events;
    for my $i (0..$#$masked) {
        my $s = $masked->[$i];
        if ($s =~ /^\s*(?:(?:my|our|state)\s+)?sub\s+([A-Za-z_]\w*(?:::\w+)*)\b/) {
            push @events, {type=>'sub',name=>$1,line=>$i+1,size=>_block_length($masked,$i),kind=>'sub'};
        }
        if ($s =~ /^\s*(?:use|require)\s+([A-Za-z_]\w*(?:::\w+)*)\b/) {
            push @events, {type=>'include',line=>$i+1,targets=>[$1]};
        }
    }
    return @events;
}

sub _extra_events {
    my ($masked, $original) = @_;
    my @events;
    for my $i (0..$#$masked) {
        my $s = $masked->[$i];
        if ($s =~ /^\s*method\s+([A-Za-z_]\w*)\b/) {
            push @events, {type=>'sub',name=>$1,line=>$i+1,size=>_block_length($masked,$i),kind=>'method'};
        }
        next unless $s =~ /^\s*(?:extends|with|use\s+(?:parent|base))\b/;
        my $part=$original->[$i];
        $part =~ s/^\s*(?:extends|with|use\s+(?:parent|base))\s*//;
        $part =~ s/\s*;.*\z//;
        $part =~ s/^-norequire\s*[,;]?\s*//;
        my @names;
        if ($part =~ /^qw\s*([\(\[\{<\/!#|])/) {
            my $open=$1; my %close=('('=>')','['=>']','{'=>'}','<'=>'>');
            my $end=$close{$open}//$open;
            if ($part =~ /\Q$open\E(.*?)\Q$end\E/) { @names=split /\s+/, $1; }
        } else {
            @names=$part =~ /['"]([A-Za-z_]\w*(?:::\w+)*)['"]/g;
        }
        @names=grep { /\A[A-Za-z_]\w*(?:::\w+)*\z/ } @names;
        push @events, {type=>'include',line=>$i+1,targets=>\@names} if @names;
    }
    return @events;
}

sub _preceding_comment {
    my ($lines,$line) = @_;
    my @parts;
    for (my $i=$line-2; $i>=0; $i--) {
        last unless $lines->[$i] =~ /^\s*#\s?(.*?)\s*\z/;
        unshift @parts, $1;
    }
    my $joined=join(' ',@parts);
    $joined =~ s/\s+/ /g;
    $joined =~ s/^\s+|\s+$//g;
    return length($joined)>180 ? substr($joined,0,177).'...' : $joined;
}

# Read source paths from a previously generated JSON without trusting paths
# that could traverse outside of the specified root (or traverse symlinks).
sub hydrate_sources {
    my ($self,$data,$dir) = @_;
    my $root=abs_path($dir // $self->{root});
    die "Source directory does not exist\n" unless $root && -d $root;
    my %paths=map { $_->{path} => 1 }
        map { @{$_->{files} || []} } @{$data->{pkgs} || []};
    $data->{sources} ||= {};
    my $count=0;
    for my $rel (sort keys %paths) {
        next if $rel =~ /\0|\\/ || $rel =~ m{\A/} || $rel =~ m{(?:\A|/)\.\.(?:/|\z)};
        my $path=File::Spec->catfile($root,split m{/},$rel);
        next unless -f $path && !-l $path && -s $path <= $self->{max_source_bytes};
        my $real=abs_path($path);
        next unless $real && index($real,"$root/")==0;
        open my $fh,'<:raw',$path or next;
        my $bytes=do { local $/; <$fh> };
        close $fh;
        $data->{sources}{$rel}=decode('UTF-8',$bytes,FB_DEFAULT);
        $count++;
    }
    return $count;
}

sub _capture {
    my (@command)=@_;
    my ($in,$out);
    my $err=gensym;
    my $pid=eval { IPC::Open3::open3($in,$out,$err,@command) };
    return undef unless $pid;
    close $in;
    my $value=do { local $/; <$out> };
    close $out;
    my $discard=do { local $/; <$err> };
    close $err;
    waitpid($pid,0);
    return undef if $?;
    $value //= '';
    $value =~ s/\s+\z//;
    return $value;
}

sub _source_info {
    my ($self)=@_;
    return ($self->{source_base},'') if defined $self->{source_base};
    my $rev=_capture('git','-C',$self->{root},'rev-parse','HEAD')//'';
    return ('','') unless $rev =~ /^[a-f0-9]{40}$/;
    my $remote=_capture('git','-C',$self->{root},'remote','get-url','origin')//'';
    my ($owner,$repo)=$remote =~ m{github\.com[:/]([^/\s:]+)/([^/\s]+?)(?:\.git)?\z};
    return ('',$rev) unless defined $owner;
    my $prefix=_capture('git','-C',$self->{root},'rev-parse','--show-prefix')//'';
    return ("https://github.com/$owner/$repo/blob/$rev/$prefix",$rev);
}

sub write_report {
    my ($self,$data,%opts) = @_;
    my $output=$opts{output}//'perl-code-map.html';
    die "Expected data with pkgs array\n" unless ref($data) eq 'HASH' && ref($data->{pkgs}) eq 'ARRAY';
    my $encoder=JSON::PP->new->canonical(1)->utf8(1);
    my $json=$encoder->encode($data);
    if ($opts{json}) {
        open my $fh,'>:raw',$opts{json} or die "Cannot write $opts{json}: $!\n";
        print {$fh} $json;
        close $fh or die "Cannot close $opts{json}: $!\n";
    }
    my $module_file=$INC{'Perl/CodeMap.pm'} // __FILE__;
    my $assets=File::Spec->catdir(dirname($module_file),'CodeMap','assets');
    my %a;
    for my $name (qw(template.html app.css app.js prism-core.min.js prism-perl.min.js)) {
        open my $fh,'<:raw',File::Spec->catfile($assets,$name)
            or die "Missing packaged report asset '$name' ($!)\n";
        $a{$name}=do { local $/; <$fh> };
        close $fh;
    }
    my $title=$data->{name}//'Perl';
    $title =~ s/&/&amp;/g;
    $title =~ s/</&lt;/g;
    $title =~ s/>/&gt;/g;
    $title =~ s/"/&quot;/g;
    $a{'template.html'} =~ s/\{\{TITLE\}\}/$title/g;
    $json =~ s/</\\u003c/g;
    $json =~ s/>/\\u003e/g;
    $json =~ s/&/\\u0026/g;
    open my $fh,'>:raw',$output or die "Cannot write $output: $!\n";
    my $html=$a{'template.html'};
    $html =~ s{<!-- STYLE -->}{'<style>' . $a{'app.css'} . '</style>'}e;
    $html =~ s{<!-- JSON -->}{'<script id="data" type="application/json">'.$json.'</script>'}e;
    $html =~ s{<!-- JS -->}{'<script>'.$a{'prism-core.min.js'}.'</script><script>'.$a{'prism-perl.min.js'}.'</script><script>'.$a{'app.js'}.'</script>'}e;
    print {$fh} $html;
    close $fh or die "Cannot close $output: $!\n";
    return $output;
}

1;

__END__

=head1 NAME

Perl::CodeMap - Static Perl package dependency map and offline source browser

=head1 SYNOPSIS

  use Perl::CodeMap;
  my $cm = Perl::CodeMap->new(root => '.', parser => 'auto');
  my $data = $cm->analyze;
  $cm->write_report($data, output => 'code-map.html', json => 'code-map.json');

=head1 DESCRIPTION

Scans Perl files without executing them, extracts package declarations,
subroutines and statically recognizable dependencies, and creates one
self-contained interactive HTML report. PPI is preferred; the limited
zero-dependency parser is an explicit fallback.

=head1 LICENSE

MIT. See LICENSE and NOTICE.md.

=cut
