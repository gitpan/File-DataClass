# @(#)$Id: 05kwalitee.t 437 2013-04-11 17:35:14Z pjf $

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.16.%d', q$Rev: 437 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   if (!-e catfile( $Bin, updir, q(MANIFEST.SKIP) )) {
      plan skip_all => 'Kwalitee test only for developers';
   }
}

eval { require Test::Kwalitee; };

plan skip_all => 'Test::Kwalitee not installed' if ($EVAL_ERROR);

Test::Kwalitee->import();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
