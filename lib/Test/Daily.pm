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
            'INCLUDE_PATH' => [ dir($_[0]->datadir, 'tt-lib')->stringify, dir($_[0]->datadir, 'tt')->stringify ]
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

sub update_site_makefile {
    my $self    = shift;
    my $tt = $self->tt;
        
    my @projects;
    while (my $file = $self->webdir->next) {
        next if not -d $file;
        next if $file eq $self->webdir;
        
        $file = basename($file);        
        next if $file eq '..';
        next if $file eq '_td'; 
               
        push @projects, $file;
    }
    
    $self->tt->process(
        'Makefile-site.tt2',
        {
            'projects' => \@projects,
            'ttdir'    => $self->ttdir,
        },
    ) || die $self->tt->error(), "\n";;
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
