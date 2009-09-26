package t::seal_0;

use warnings;
use strict;

use Test::More;

BEGIN { is $^H{"Lexical::SealRequireHints/test"}, undef; }

is $^H{"Lexical::SealRequireHints/test"}, undef;

sub import {
	is $^H{"Lexical::SealRequireHints/test"}, 1;
	$^H |= 0x20000 if $] < 5.009004;
	$^H{"Lexical::SealRequireHints/test0"}++;
}

1;
