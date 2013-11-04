#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

=head1 DESCRIPTION

=head1 SYNOPSIS

=head1 SUBS

=head2 main

sub main {
    my ( $help, $man );

    my $result = GetOptions (
	"help|h"    => \$help,
	"verbose|v"   =>  \$verbose,
	"man|m"      => \$man
	);

    if ( $man ) { pod2usage( -verbose => 2 ); }

    if ( ! ( $server ) || $help )
    {
	pod2usage(1);
    }


}

main();

=head1 AUTHOR


(>>>USER_NAME<<<) <(>>>AUTHOR<<<)>

=head1 LICENSE

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
