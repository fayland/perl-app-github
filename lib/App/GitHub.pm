package App::GitHub;

use strict;
use warnings;

# ABSTRACT: GitHub Command Tools

use Moose;
use Net::GitHub;
use Term::ReadLine;
use JSON::XS;

our $VERSION = '0.03';

# Copied from Devel-REPL
has 'term' => (
  is => 'rw', required => 1,
  default => sub { Term::ReadLine->new('Perl-App-GitHub') }
);
has 'prompt' => (
  is => 'rw', required => 1,
  default => sub { 'github> ' }
);

has 'out_fh' => (
  is => 'rw', required => 1, lazy => 1,
  default => sub { shift->term->OUT || \*STDOUT; }
);

sub print {
    my ($self, @ret) = @_;
    my $fh = $self->out_fh;
    no warnings 'uninitialized';
    print $fh "@ret";
    print $fh "\n" if $self->term->ReadLine =~ /Gnu/;
}
sub read {
    my ($self, $prompt) = @_;
    $prompt ||= $self->prompt;
    return $self->term->readline($prompt);
}

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
    'q'     => sub { exit; },
    '?'     => \&help,
    'h'     => \&help,

    # Common
    repo    => \&set_repo,
    login   => \&set_login,
    loadcfg => \&set_loadcfg,
    
    # Repo
    rshow    => \&repo_show,
    rlist    => \&repo_list,
    findrepo => sub {
        my ( $self, $word ) = @_;
        $self->run_github( "repos->search('$word')" );
    },
    watch    => sub { shift->run_github( 'repos->watch()' ); },
    unwatch  => sub { shift->run_github( 'repos->unwatch()' ); },
    fork     => sub { shift->run_github( 'repos->fork()' ); },
    create   => \&repo_create,
    delete   => \&repo_delete,
    set_private => sub { shift->run_github( 'repos->set_private()' ); },
    set_public  => sub { shift->run_github( 'repos->set_public()' ); },
    # XXX? TODO, deploy_keys collaborators
    network     => sub { shift->run_github( 'repos->network()' ); },
    tags        => sub { shift->run_github( 'repos->tags()' ); },
    branches    => sub { shift->run_github( 'repos->branches()' ); },
    
    # Issues
    ilist    => sub {
        my ( $self, $type ) = @_;
        $type ||= 'open';
        $self->run_github( "issue->list('$type')" );
    },
    iview    => sub {
        my ( $self, $number ) = @_;
        $self->run_github( "issue->view($number)" ); 
    },
    iopen    => \&issue_open,
    iclose   => sub {
        my ( $self, $number ) = @_;
        $self->run_github( "issue->close($number)" ); 
    },
    ireopen  => sub {
        my ( $self, $number ) = @_;
        $self->run_github( "issue->reopen($number)" ); 
    },
    # XXX? TODO, add_label, edit etc
    ilabel   => \&issue_label,
    
    
    # File/Path
    cd      => sub {
        my ( $self, $args ) = @_;
        eval("chdir $args");
        $self->print($@) if $@;
    },
};

sub run {
    my $self = shift;

    $self->print(<<START);

Welcome to GitHub Command Tools! (Ver: $VERSION)
Type '?' or 'h' for help.
START

    while ( defined (my $command = $self->read) ) {

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
                $self->print("Unknown command, type '?' or 'h' for help");
                next unless $command;
            }
        }

        $self->term->addhistory($command) if $command =~ /\S/;
    }
}

sub help {
    my $self = shift;
    $self->print(<<HELP);
 command  argument          description
 repo     :user :repo       set owner/repo, eg: 'fayland perl-app-github'
 login    :login :token     authenticated as :login
 loadcfg                    authed by git config --global github.user|token
 ?,h                        help
 q,exit,quit                exit

Repos
 rshow                      more in-depth information for the :repo in repo
 rlist                      list out all the repositories for the :user in repo
 rsearch  WORD              Search Repositories
 watch                      watch repositories (authentication required)
 unwatch                    unwatch repositories (authentication required)
 fork                       fork a repository (authentication required)
 create                     create a new repository (authentication required)
 delete                     delete a repository (authentication required)
 set_private                set a public repo private (authentication required)
 set_public                 set a private repo public (authentication required)
 network                    see all the forks of the repo
 tags                       tags on the repo
 branches                   list of remote branches

Issues
 ilist    open|closed       see a list of issues for a project
 iview    :number           get data on an individual issue by number
 iopen                      open a new issue (authentication required)
 iclose   :number           close an issue (authentication required)
 ireopen  :number           reopen an issue (authentication required)
 ilabel   add|remove :num :label
                            add/remove a label (authentication required)

File/Path related
 cd       PATH              chdir to PATH

Others
 rshow    :user :repo       more in-depth information for a repository
 rlist    :user             list out all the repositories for a user
HELP
}

sub set_repo {
    my ( $self, $repo ) = @_;
    
    # validate
    unless ( $repo =~ /^([\-\w]+)[\/\\\s]([\-\w]+)$/ ) {
        $self->print("Wrong repo args ($repo), eg fayland/perl-app-github");
        return;
    }
    my ( $owner, $name ) = ( $repo =~ /^([\-\w]+)[\/\\\s]([\-\w]+)$/ );
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
        $self->print("Wrong login args ($login $token), eg fayland 54b5197d7f92f52abc5c7149b313cf51");
        return;
    }

    $self->_do_login( $login, $token );
}

sub set_loadcfg {
    my ( $self ) = @_;
    
    my $login = `git config --global github.user`;
    my $token = `git config --global github.token`;
    chomp($login); chomp($token);
    unless ( $login and $token ) {
        $self->print("run git config --global github.user|token fails");
        return;
    }
    
    $self->_do_login( $login, $token );
}

sub _do_login {
    my ( $self, $login, $token ) = @_;
    
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
        $self->print(<<'ERR');
unknown repo. try 'repo :owner :repo' first
ERR
        return;
    }
    
    eval(qq~\$self->print(JSON::XS->new->utf8->pretty->encode(\$self->github->$command))~);
    
    if ( $@ ) {
        # custom error
        if ( $@ =~ /login and token are required/ ) {
            $self->print(<<'ERR');
authentication required. try 'login :owner :token' first
ERR
        } else {
            $self->print($@);
        }
    }
}

################## Repos
sub repo_show {
    my ( $self, $args ) = @_;
    if ( $args and $args =~ /^([\-\w]+)[\/\\\s]([\-\w]+)$/ ) {
        $self->run_github("repos->show('$1', '$2')");
    } else {
        $self->run_github('repos->show()');
    }
}

sub repo_list {
    my ( $self, $args ) = @_;
    if ( $args and $args =~ /^[\w\-]+$/ ) {
        $self->run_github("repos->list('$args')");
    } else {
        $self->run_github('repos->list()');
    }
}

sub repo_create {
    my ( $self ) = @_;
    
    my %data;
    foreach my $col ( 'name', 'desc', 'homepage' ) {
        my $data = $self->read( ucfirst($col) . ': ' );
        $data{$col} = $data;
    }
    unless ( length( $data{name} ) ) {
        $self->print('create repo failed. name is required');
        return;
    }
    
    $self->run_github( qq~repos->create( "$data{name}", "$data{desc}", "$data{homepage}", 1 )~ );
}

sub repo_del {
    my ( $self ) = @_;
    
    my $data = $self->read( 'Are you sure to delete the repo? [YN]? ' );
    if ( $data eq 'Y' ) {
        $self->print("Deleting Repos ...");
        $self->run_github( "repos->delete( { confirm => 1 } )" );
    }
}

# Issues
sub issue_open {
    my ( $self ) = @_;
    
    my %data;
    foreach my $col ( 'title', 'body' ) {
        my $data = $self->read( ucfirst($col) . ': ' );
        $data{$col} = $data;
    }

    $self->run_github( qq~issue->open( "$data{title}", "$data{body}" )~ );
}

sub issue_label {
    my ( $self, $args ) = @_;
    
    no warnings 'uninitialized';
    my ( $type, $number, $label ) = split(/\s+/, $args, 3);
    if ( $type eq 'add' ) {
        $self->run_github( qq~issue->add_label( $number, '$label' )~ );
    } elsif ( $type eq 'remove' ) {
        $self->run_github( qq~issue->remove_label( $number, '$label' )~ );
    } else {
        $self->print('unknown argument. ilabel add|remove :number :label');
    }
}

1;