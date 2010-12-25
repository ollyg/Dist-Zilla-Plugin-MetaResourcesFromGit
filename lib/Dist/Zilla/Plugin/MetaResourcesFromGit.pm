package Dist::Zilla::Plugin::MetaResourcesFromGit;
BEGIN {
  $Dist::Zilla::Plugin::MetaResourcesFromGit::VERSION = '1.103590';
}

use Moose;
with 'Dist::Zilla::Role::MetaProvider';

# both available due to Dist::Zilla
use Path::Class 'dir';
use Config::INI::Reader;

our %transform = (
  'lc' => sub { lc shift },
  'uc' => sub { uc shift },
  deb  => sub { 'lib'. (lc shift) .'-perl' },
  ''   => sub { shift },
);

use String::Formatter method_stringf => {
    -as => '_format_string',
    codes => {
        a => sub { $_[0]->_github->{'account'} },
        r => sub { $_[0]->_github->{'project'} },
        N => sub { $transform{$_[1] || ''}->( $_[0]->name ) },
    },
};

has name => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { $_[0]->zilla->name },
);

has remote => (
    is      => 'ro',
    isa     => 'Str',
    default => 'origin',
);

has homepage => (
    is      => 'ro',
    isa     => 'Str',
    default => 'http://github.com/%a/%r/wiki',
);

has bugtracker_web => (
    is      => 'ro',
    isa     => 'Str',
    default => 'https://rt.cpan.org/Public/Dist/Display.html?Name=%N',
);

has repository_url => (
    is      => 'ro',
    isa     => 'Str',
    default => 'git://github.com/%a/%r.git',
);

has _github => (
    is         => 'ro',
    isa        => 'HashRef[Str]',
    lazy_build => 1,
);

sub _build__github {
    my $self = shift;

    my $root = dir('.git');
    my $ini = $root->file('config');

    die "GitHubMeta: need a .git/config file, and you don't have one\n"
        unless -e $ini;

    my $fh = $ini->openr;
    my $config = Config::INI::Reader->read_handle($fh);

    my $remote = $self->remote;
    die "GitHubMeta: no '$remote' remote found in .git/config\n"
        unless exists $config->{qq{remote "$remote"}};

    my $url = $config->{qq{remote "$remote"}}->{'url'};
    die "GitHubMeta: no url found for remote '$remote'\n"
        unless $url and length $url;

    my ($account, $project) = ($url =~ m{[:/](.+)/(.+)\.git$});

    die "GitHubMeta: no github account name found in .git/config\n"
        unless $account and length $account;
    die "GitHubMeta: no github repository (project) found in .git/config\n"
        unless $project and length $project;

    return { account => $account, project => $project };
}

sub BUILDARGS {
    my ($class, @arg) = @_;
    my %attr = ref $arg[0] ? %{ $arg[0] } : @arg;

    if (exists $attr{'bugtracker.web'}) {
        $attr{'bugtracker_web'} = delete $attr{'bugtracker.web'};
    }

    if (exists $attr{'repository.url'}) {
        $attr{'repository_url'} = delete $attr{'repository.url'};
    }

    return \%attr;
}

sub metadata {
    my ($self) = @_;

    return {
        resources => {
            homepage => _format_string($self->homepage, $self),
            bugtracker => { web => _format_string($self->bugtracker_web, $self) },
            repository => { url => _format_string($self->repository_url, $self) },
        },
    };
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

# ABSTRACT: Metadata resource URLs from Git configuration



__END__
=pod

=head1 NAME

Dist::Zilla::Plugin::MetaResourcesFromGit - Metadata resource URLs from Git configuration

=head1 VERSION

version 1.103590

=head1 SYNOPSIS

In your C<dist.ini> or C<profile.ini>:

 [MetaResourcesFromGit]

=head1 DESCRIPTION

This plugin is a drop-in replacement for L<Dist::Zilla::Plugin::MetaResources>
for users of Git. It provides three resource links to your distribution
metadata, based on the name of the distribution and the remote URL of the Git
repository you are working from.

The default links are equivalent to:

 homepage       = http://github.com/%a/%r/wiki
 bugtracker.web = https://rt.cpan.org/Public/Dist/Display.html?Name=%N
 repository.url = git://github.com/%a/%r.git

=head1 CONFIGURATION

=head2 Plugin Options

=over 4

=item C<name>

The name of your Perl distribution in the format used by CPAN. It defaults to
the C<name> option you have provided in C<dist.ini>.

=item C<remote>

The alias of the Git remote URL from which the working repository is cloned.
It defaults to C<origin>.

=item C<homepage>

A link on the CPAN page of your distribution, defaulting to the wiki page of a
constructed L<http://github.com> repository for your code. You can use the
formatting options below when overriding this value.

=item C<bugtracker.web>

A link on the CPAN page of your distribution, defaulting to its corresponding
L<http://rt.cpan.org> homepage. You can use the formatting options below when
overriding this value.

=item C<repository.url>

A link on the CPAN page of your distribution, defaulting to the read-only
clone URL belonging to a contructed L<http://github.com> repository for your
code. You can use the formatting options below when overriding this value.

=back

=head2 Formatting Options

The following codes may be used when overriding the C<homepage>,
C<bugtracker.web>, and C<repository.url> configuration options.

=over 4

=item C<%a>

The "account" (username) as parsed from the remote repository URL in the local
Git configuration. This is currently (probably) GitHub-centric.

=item C<%r>

The "repository" (or, project name) as parsed from the remote repiository URL
in the local Git configuration. This is currently (probably) GitHub-centric.

=item C<%N>

The name of the distribution as given to the C<name> option in your
C<dist.ini> file. You can also use C<< %{lc}N >> or C<< %{uc}N >> to get the
name in lower or upper case respectively, or C<< %{deb}N >> to get the name in
a Debian GNU/Linux package-name format (C<lib-foo-bar-perl>).

=back

=head1 TODO

=over 4

=item * Make things less GitHub-centric. Patches welcome!

=back

=head1 THANKS

To C<cjm> from IRC for suggesting this as a better way to achieve my requirements.

=head1 AUTHOR

Oliver Gorwits <oliver@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Oliver Gorwits.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

