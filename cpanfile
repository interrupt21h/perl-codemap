requires 'perl', '5.020';
requires 'JSON::PP';
recommends 'PPI', '1.291';
on 'test' => sub {
    requires 'Test::More';
    requires 'File::Temp';
};
