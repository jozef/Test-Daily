use strict;
use warnings;
use Module::Build::SysPath;

use 5.010;

my $builder = Module::Build::SysPath->new(
    module_name         => 'Test::Daily',
    license             => 'perl',
    dist_author         => 'Jozef Kutej <jkutej@cpan.org>',
    dist_version_from   => 'lib/Test/Daily.pm',
    requires => {
        'JSON::Util'   => 0,
    },
    configure_requires => {
        'Module::Build::SysPath' => 0.08,
    },
    build_requires => {
        'Module::Build::SysPath' => 0.08,
        'Test::More'        => 0,
        'Test::Differences' => 0,
        'File::Temp'        => 0,
    },
    script_files => [
        'script/test-daily',
    ],
    webdir_files => {
        'www/test-daily/_td/default_page.css' => '',
        'www/test-daily/_td/default_report.css' => '',
        'www/test-daily/_td/default_report.js' => '',
        'www/test-daily/_td/jquery-1.3.2.js' => '',
    },
    conffiles => [
        [ 'conf', 'test-daily', 'test-daily.conf' ],
    ],
    add_to_cleanup      => [ 'Test-Daily-*' ],
    create_readme       => 1,
    sign                => 1,
);

$builder->create_build_script();
