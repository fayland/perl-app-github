#!/usr/bin/perl

# ABSTRACT: GitHub Command Tools

use strict;
use warnings;

use App::GitHub;

App::GitHub->new->run(@ARGV);

=head1 SYNOPSIS
 
    $ github.pl

     command   argument          description
     repo      :user :repo       set owner/repo, eg: 'fayland perl-app-github'
     login     :login :token     authenticated as :login
     loadcfg                     authed by git config --global github.user|token
     ?,h                         help
     q,exit,quit                 exit
    
    Repos
     r.show                      more in-depth information for the :repo
     r.list                      list out all the repositories for the :user
     r.search WORD               Search Repositories
     r.watch                     watch repositories (auth required)
     r.unwatch                   unwatch repositories (auth required)
     r.fork                      fork a repository (auth required)
     r.create                    create a new repository (auth required)
     r.delete                    delete a repository (auth required)
     r.set_private               set a public repo private (auth required)
     r.set_public                set a private repo public (auth required)
     r.network                   see all the forks of the repo
     r.tags                      tags on the repo
     r.branches                  list of remote branches
    
    Issues
     i.list    open|closed       see a list of issues for a project
     i.view    :number           get data on an individual issue by number
     i.search  open|closed WORD  Search Issues
     i.open                      open a new issue (auth required)
     i.close   :number           close an issue (auth required)
     i.reopen  :number           reopen an issue (auth required)
     i.edit    :number           edit an issue (auth required)
     i.comment :number
     i.label   add|del :num :label
                                 add/remove a label (auth required)
    
    Users
     u.search  WORD              search user
     u.show                      get extended information on user
     u.update                    update your users info (auth required)
     u.followers
     u.following
     u.follow  :user             follow :user (auth required)
     u.unfollow :user            unfollow :user (auth required)
     u.pub_keys                  Public Key Management (auth required)
     u.pub_keys.add
     u.pub_keys.del :number
    
    Commits
     c.branch  :branch           list commits for a branch
     c.file    :branch :file     get all the commits modified the file
     c.file    :file             (default branch 'master')
     c.show    :sha1             show a specific commit
    
    Objects
     o.tree    :tree_sha1        get the contents of a tree by tree sha
     o.blob    :tree_sha1 :file  get the data of a blob by tree sha and path
     o.raw     :sha1             get the data of a blob (tree, file or commits)
    
    Network
     n.meta                      network meta
     n.data_chunk :net_hash      network data
    
    Others
     r.show    :user :repo       more in-depth information for a repository
     r.list    :user             list out all the repositories for a user
     u.show    :user             get extended information on :user

=head1 DESCRIPTION

a command line tool wrap L<Net::GitHub>

Repository: L<http://github.com/fayland/perl-app-github/tree/master>
 
=head1 SEE ALSO
 
L<Net::GitHub>
 
=cut

1;