package Test::Daily;

=head1 NAME

=head1 SYNOPSIS

    use Test::Daily;
    my $td = Test::Daily->new();
    $td->process_tarball('my-test-tap-archive.tar.gz');
    
=head1 DESCRIPTION

=cut

use Moose;
use Test::Daily::SPc;
use Config::Tiny;
use Carp 'croak';
use File::Path 'mkpath';
use File::Basename 'basename';
use Archive::Extract;
use Path::Class 'dir', 'file';
use Template;
use Template::Constants qw( :debug );
use TAP::Formatter::HTML '0.08';
use TAP::Harness;

our $VERSION = '0.01';

has 'datadir' => (
    is      => 'rw',
    isa     => 'Path::Class::Dir',
    default => sub { dir(Test::Daily::SPc->datadir, 'test-daily') },
    lazy    => 1,
);
has 'webdir' => (
    is      => 'rw',
    isa     => 'Path::Class::Dir',
    default => sub { dir(Test::Daily::SPc->webdir, 'test-daily') },
    lazy    => 1,
);
has 'config_file' => (
    is      => 'rw',
    isa     => 'Path::Class::Dir',
    default => sub { dir(Test::Daily::SPc->sysconfdir, 'test-daily', 'test-daily.conf') },
    lazy    => 1,
);
has 'config' => (
    is      => 'rw',
    isa     => 'Config::Tiny',
    default => sub { Config::Tiny->read( $_[0]->config_file ) or die 'failed to open config file - "'.$_[0]->config_file.'"' },
    lazy    => 1,
);
has 'tt_config' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {
        $_[0]->config->{'tt'}
        || {
            'INCLUDE_PATH' => [ dir($_[0]->datadir, 'tt-lib')->stringify, dir($_[0]->datadir, 'tt')->stringify ],
            'DEBUG'        => DEBUG_UNDEF,
            'OUTPUT_PATH'  => $_[0]->webdir->stringify,
        }
    },
    lazy    => 1,
);
has 'ttdir' => (
    is      => 'rw',
    isa     => 'Path::Class::Dir',
    default => sub { dir($_[0]->datadir, 'tt') },
    lazy    => 1,
);
has 'site_prefix' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { $_[0]->config->{'main'}->{'site_prefix'} || '/test-server/' },
    lazy    => 1,
);
has 'tt' => (
    is      => 'rw',
    isa     => 'Template',
    default => sub { Template->new($_[0]->tt_config) || die $Template::ERROR, "\n" },
    lazy    => 1,
);


=head1 METHODS

=head2 new()

Object constructor.

=cut

sub extract_tarball {
    my $self    = shift;
    my $tarball = shift or croak 'pass tarball as argument';
    
    croak 'tarball name "'.basename($tarball).'" format unknown'
        if basename($tarball) !~ m/^(.+)_(.+)_(.+)\.(?:tar\.gz|zip)$/xms;
    my ($name, $version, $arch) = ($1, $2, $3);
    
    my $ae = Archive::Extract->new( archive => $tarball );
    my $extract_to;
    my $i = 0;
    my $index = '';
    do {
        $extract_to = dir($self->webdir, $name, $version.'_'.$arch.$index);
        $index = sprintf('_%03d', $i);
        $i++;
    } while -d $extract_to;
    mkpath($extract_to);
    $ae->extract( to => $extract_to);
}

sub _update_makefile {
    my $self          = shift;
    my $makefile_type = shift or die 'set type parameter';
    my @path          = @_;

    my $path          = dir($self->webdir, @path);

    my $tt = $self->tt;
        
    my @folders;
    while (my $file = $path->next) {
        next if not -d $file;
        next if $file eq $path;
        
        $file = basename($file);        
        next if $file eq '..';
        next if $file eq '_td'; 
               
        push @folders, $file;
    }
    
    $self->tt->process(
        'Makefile-'.$makefile_type.'.tt2',
        {
            'folders' => \@folders,
            'ttdir'   => $self->ttdir,
            'path'    => dir(@path)->stringify,
        },
        file(@path, 'Makefile')->stringify,
    ) || die $self->tt->error(), "\n";;
}

sub update_site_makefile {
    my $self = shift;
    $self->_update_makefile('site');
}
sub update_build_makefile {
    my $self = shift;
    $self->_update_makefile('build', @_);
}
sub update_build_summary {
    my $self = shift;
    
    my @tests = glob( 't/*.t' );
    my $fmt = TAP::Formatter::HTML->new;
    $fmt
        ->js_uris([$self->config->{'main'}->{'site_prefix'}.'_td/jquery-1.3.2.js', $self->config->{'main'}->{'site_prefix'}.'_td/default_report.js' ])
        ->css_uris([$self->config->{'main'}->{'site_prefix'}.'_td/default_page.css', $self->config->{'main'}->{'site_prefix'}.'_td/default_report.css'])
        ->inline_css('')
        ->force_inline_css(0)
        ->inline_js('');
    $fmt->output_file('index.html-new');
    $fmt->verbosity(-2);

    my $harness = TAP::Harness->new({
        formatter => $fmt,
        merge     => 1,
        lib       => [ 'lib', 'blib/lib', 'blib/arch' ],
        exec      => [ 'cat' ],
    });

    my $aggregate = $harness->runtests( @tests );

    # write test summary
    my @aggregate_methods = qw(
        get_status
        elapsed_timestr
        all_passed
        
        failed
        parse_errors
        passed
        planned
        skipped
        todo
        todo_passed
        wait
        exit
        
        total
        has_problems
        has_errors
    );
    JSON::Util->encode(
        { map { $_ => [ $aggregate->$_ ] } @aggregate_methods },
        'summary.json'
    );
    
    rename('index.html-new', 'index.html');
}

sub update_project_makefile {
    my $self = shift;
    $self->_update_makefile('project', @_);
}

1;


__END__

=head1 AUTHOR

Jozef Kutej

=cut

=head1 AUTHOR

Jozef Kutej, C<< <jkutej at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-daily at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Daily>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Daily


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Daily>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Daily>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Daily>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Daily>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Test::Daily
