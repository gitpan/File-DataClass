# @(#)$Id: 06yaml.t 429 2013-01-07 00:49:36Z pjf $

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.14.%d', q$Rev: 429 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   if (!-e catfile( $Bin, updir, q(MANIFEST.SKIP) )) {
      plan skip_all => 'YAML test only for developers';
   }
}

eval { require Test::YAML::Meta; };

plan skip_all => 'Test::YAML::Meta not installed' if ($EVAL_ERROR);

Test::YAML::Meta->import();

meta_yaml_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
