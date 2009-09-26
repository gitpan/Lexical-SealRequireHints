if($] < 5.008) {
	require Test::More;
	Test::More::plan(skip_all =>
		"pure Perl Lexical::SealRequireHints can't work on this perl");
}

require XSLoader;

my $orig_load = \&XSLoader::load;
no warnings "redefine";
*XSLoader::load = sub {
	die "XS loading disabled for Lexical::SealRequireHints"
		if $_[0] eq "Lexical::SealRequireHints";
	goto &$orig_load;
};

1;
