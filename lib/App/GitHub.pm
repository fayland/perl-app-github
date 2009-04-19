package App::GitHub;

use strict;
use warnings;

# ABSTRACT: GitHub Command Tools

use Moose;
use Net::GitHub;
use Term::ReadLine;
use JSON::XS;

our $VERSION = '0.02';

has 'term' => (
    is  => 'ro',
    isa => 'Object',
    default => sub {
        my $term = new Term::ReadLine 'github';
    
        my $odef = select STDERR;
        $| = 1;
        select STDOUT;
        $| = 1;
        select $odef;
        
        return $term;
    }
);
has 'prompt' => (
    is => 'rw', isa => 'Str', default => "github> ",
);

has 'github' => (
    is  => 'rw',
    isa => 'Net::GitHub',
);

has '_data' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

=head1 SYNOPSIS
 
    github.pl
 
=head1 DESCRIPTION

a command line tool wrap L<Net::GitHub>

=head1 ALPHA WARNING

L<App::GitHub> is still in its infancy. lots of TODO

feel free to fork from L<http://github.com/fayland/perl-app-github/tree/master>
 
=head1 SEE ALSO
 
L<Net::GitHub>
 
=cut

my $dispatch = {
    'exit'  => sub { exit; },
    'quit'  => sub { exit; },
    '?'     => \&help,
    'h'     => \&help,

    # Common
    repo    => \&set_repo,
    login   => \&set_login,
    
    # Repo
    show    => sub {
        my ( $self, $args ) = @_;
        if ( $args and $args =~ /^([\-\w]+)[\/\\]([\-\w]+)$/ ) {
            $self->run_github("repos->show('$1', '$2')");
        } else {
            $self->run_github('repos->show()');
        }
    },
    list    => sub {
        my ( $self, $args ) = @_;
        if ( $args and $args =~ /^[\w\-]+$/ ) {
            $self->run_github("repos->list('$args')");
        } else {
            $self->run_github('repos->list()');
        }
    },
    
    watch   => sub { shift->run_github( 'repos->watch()' ); },
    unwatch => sub { shift->run_github( 'repos->unwatch()' ); },
    
    # File/Path
    cd      => sub {
        eval("chdir " . shift);
        print $@ if $@;
    },
};

sub run {
    my $self = shift;

    print <<START;

Welcome to GitHub Command Tools! (Ver: $VERSION)
Type '?' or 'h' for help.
START

    while ( defined (my $command = $self->term->readline($self->prompt)) ) {

        $command =~ s/(^\s+|\s+$)//g;
        next unless length($command);

        # check dispatch
        if ( exists $dispatch->{$command} ) {
            $dispatch->{$command}->( $self );
        } else {
            # split the command out
            ( $command, my $args ) = split(/\s+/, $command, 2);
            if ( $command and exists $dispatch->{$command} ) {
                $dispatch->{$command}->( $self, $args );
            } else {
                print "Unknown command, type '?' or 'h' for help\n";
                next unless $command;
            }
        }

        $self->term->addhistory($command) if $command =~ /\S/;
    }
}

sub help {
    print <<HELP;
 command  argument          description
 repo     :user/:repo       set owner/repo
                            eg: 'fayland/perl-app-github'
 login    :login :token     authenticated as :login
 ?,h                        help

Repos
 show     ?:user/:repo      more in-depth information for a repository
                            (default by repo command)
 list     ?:user            list out all the repositories for a user
                            (default by repo command)
 watch                      watch repositories (authentication required)
 unwatch                    unwatch repositories (authentication required)

File/Path related
 cd       PATH              chdir to PATH

HELP
}

sub set_repo {
    my ( $self, $repo ) = @_;
    
    # validate
    unless ( $repo =~ /^([\-\w]+)[\/\\]([\-\w]+)$/ ) {
        print "Wrong repo args ($repo), eg fayland/perl-app-github\n";
        return;
    }
    my ( $owner, $name ) = ( $repo =~ /^([\-\w]+)[\/\\]([\-\w]+)$/ );
    $self->{_data}->{owner} = $owner;
    $self->{_data}->{repo} = $name;
    
    # when call 'login' before 'repo'
    my @logins = ( $self->{_data}->{login} and $self->{_data}->{token} ) ? (
        login => $self->{_data}->{login}, token => $self->{_data}->{token}
    ) : ();
    
    $self->{github} = Net::GitHub->new(
        owner => $owner, repo => $name,
        @logins,
    );
    $self->{prompt} = "$owner/$name> ";
}

sub set_login {
    my ( $self, $login ) = @_;
    
    ( $login, my $token ) = split(/\s+/, $login, 2);
    unless ( $login and $token ) {
        print "Wrong login args ($login $token), eg fayland 54b5197d7f92f52abc5c7149b313cf51\n";
        return;
    }
    
    # save for set_repo
    $self->{_data}->{login} = $login;
    $self->{_data}->{token} = $token;

    if ( $self->github ) {
        $self->{github} = Net::GitHub->new(
            owner => $self->{_data}->{owner}, repo  => $self->{_data}->{repo},
            login => $self->{_data}->{login}, token => $self->{_data}->{token}
        );
    }
}

sub run_github {
    my ( $self, $command ) = @_;
    
    unless ( $self->github ) {
        print <<'ERR';
unknown repo. try 'repo :owner/:repo' first
ERR
        return;
    }
    
    eval(qq~print JSON::XS->new->utf8->pretty->encode(\$self->github->$command) . "\n"~);
    
    if ( $@ ) {
        # custom error
        if ( $@ =~ /login and token are required/ ) {
            print <<'ERR';
authentication required. try 'login :owner :token' first
ERR
        } else {
            print $@;
        }
    }
}

1;