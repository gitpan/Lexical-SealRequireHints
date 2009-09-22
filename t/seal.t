use warnings;
use strict;

use Test::More tests => 21;

BEGIN { use_ok "Lexical::SealRequireHints"; }

BEGIN { $^H{"Lexical::SealRequireHints/test"} = 1; }

BEGIN { is $^H{"Lexical::SealRequireHints/test"}, 1; }
use t::seal_0;
BEGIN {
	is $^H{"Lexical::SealRequireHints/test"}, 1;
	require t::seal_1;
	t::seal_1->import;
	is $^H{"Lexical::SealRequireHints/test"}, 1;
}

BEGIN { is $^H{"Lexical::SealRequireHints/test"}, 1; }
use t::seal_0;
BEGIN {
	is $^H{"Lexical::SealRequireHints/test"}, 1;
	require t::seal_1;
	t::seal_1->import;
	is $^H{"Lexical::SealRequireHints/test"}, 1;
}

BEGIN {
	is $^H{"Lexical::SealRequireHints/test"}, 1;
	is $^H{"Lexical::SealRequireHints/test0"}, 2;
	is $^H{"Lexical::SealRequireHints/test1"}, 2;
}

BEGIN { is +(1 + require t::seal_2), 11; }

BEGIN {
	eval { require t::seal_3; };
	like $@, qr/\Aseal_3 death\n/;
}

BEGIN {
	eval { require t::seal_4; };
	like $@, qr/\Aseal_4 death\n/;
}

1;
