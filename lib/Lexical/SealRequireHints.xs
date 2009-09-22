#define PERL_CORE 1   /* required in order to get working SAVEHINTS() */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define PERL_VERSION_DECIMAL(r,v,s) (r*1000000 + v*1000 + s)
#define PERL_DECIMAL_VERSION \
	PERL_VERSION_DECIMAL(PERL_REVISION,PERL_VERSION,PERL_SUBVERSION)
#define PERL_VERSION_GE(r,v,s) \
	(PERL_DECIMAL_VERSION >= PERL_VERSION_DECIMAL(r,v,s))

static OP *pp_squashhints(pTHX)
{
	SAVEHINTS();
	hv_clear(GvHV(PL_hintgv));
#if PERL_VERSION_GE(5,9,4)
	if(PL_compiling.cop_hints_hash) {
		Perl_refcounted_he_free(aTHX_ PL_compiling.cop_hints_hash);
		PL_compiling.cop_hints_hash = NULL;
	}
#endif /* >=5.9.4 */
	return PL_op->op_next;
}

static OP *(*next_ck_require)(pTHX_ OP *o);

static OP *ck_require_for_hintseal(pTHX_ OP *o)
{
	OP *squashhints_op;
	o = next_ck_require(aTHX_ o);
	squashhints_op = newOP(OP_PUSHMARK, 0);
	squashhints_op->op_ppaddr = pp_squashhints;
	o = newBINOP(OP_NULL, 0, squashhints_op, o);
	return newWHILEOP(0, 1, NULL, 0, NULL, o, NULL
#if PERL_VERSION_GE(5,9,3)
				, 0
#endif /* >=5.9.3 */
			);
}

MODULE = Lexical::SealRequireHints PACKAGE = Lexical::SealRequireHints

void
import(SV *class)
CODE:
	if(!next_ck_require) {
		next_ck_require = PL_check[OP_REQUIRE];
		PL_check[OP_REQUIRE] = ck_require_for_hintseal;
	}
