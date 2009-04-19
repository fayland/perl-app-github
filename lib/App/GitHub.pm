package App::GitHub;

use strict;
use warnings;

# ABSTRACT: GitHub Command Tools

use Moose;
use Net::GitHub;
use Term::ReadLine;

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
    predicate => 'repo_is_set',
);

=head1 SYNOPSIS
 
    github.pl
 
=head1 DESCRIPTION

a command line tool wrap L<Net::GitHub>
 
=head1 SEE ALSO
 
L<Net::GitHub>
 
=cut

my $dispatch = {
    'exit'  => sub { exit; },
    'quit'  => sub { exit; },
    '?'     => \&help,
    'h'     => \&help,
    
    # Repo
    repo    => \&set_repo,
    
    # File/Path
    cd      => sub {
        eval("chdir " . shift);
        print $@ if $@;
    },
};

sub run {
    my $self = shift;

    print <<'START';

Welcome to GitHub Command Tools!
Type '?' or 'h' for help.
START

    while ( defined (my $command = $self->term->readline($self->prompt)) ) {

        $command =~ s/(^\s+|\s+$)//g;

        # check dispatch
        if ( exists $dispatch->{$command} ) {
            $dispatch->{$command}->( $self );
        } else {
            # split the command out
            ( $command, my $args ) = split(/\s+/, $command, 2);
            if ( exists $dispatch->{$command} ) {
                $dispatch->{$command}->( $self, $args );
            } else {
                print "Unknown command, type '?' or 'h' for help\n";
            }
        }

        $self->term->addhistory($command) if $command =~ /\S/;
    }
}

sub help {
    print <<HELP;
 command  argument          description
 
 repo     WORD              set owner/repo like 'fayland/perl-app-github'
 ?,h                        help

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
    $self->{github} = Net::GitHub->new(
        owner => $owner, repo => $name
    );
    $self->{prompt} = "$owner/$name> ";
}

1;