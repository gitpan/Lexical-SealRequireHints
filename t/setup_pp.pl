require XSLoader;

my $orig_load = \&XSLoader::load;
no warnings "redefine";
*XSLoader::load = sub {
	die "XS loading disabled for Lexical::SealRequireHints"
		if $_[0] eq "Lexical::SealRequireHints";
	goto &$orig_load;
};

1;
