# @(#)$Ident: Build.PL 2013-08-13 17:55 pjf ;

use strict;
use warnings;

use Module::Build;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

$] >= 5.01 or whimper "Minimum required Perl version is 5.01";

my $code = do { local $/; <DATA> };

Module::Build->subclass( code => $code )->new(
  'module_name' => 'File::DataClass',
  'notes'       => { min_perl_version => 5.01 },
  'share_dir'   => -d 'share' ? 'share' : undef,
  'build_requires' => {
    'File::pushd' => '1.00',
    'Module::Build' => '0.4004',
    'Test::Deep' => '0.108',
    'Text::Diff' => '1.37',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'CHI' => '0.58',
    'Cache::FastMmap' => '1.36',
    'Class::Load' => '0.18',
    'Class::Method::ModifiersX::Augment' => '0.001',
    'Class::Null' => '2.101420',
    'File::Path' => '2.08',
    'Hash::Merge' => '0.12',
    'JSON' => '2.50',
    'Moo' => '1.003',
    'MooX::ClassStash' => '0.005',
    'Try::Tiny' => '0.09',
    'Type::Tiny' => '0.012',
    'Unexpected' => 'v0.6.0',
    'XML::Bare' => '0.47',
    'XML::Simple' => '2.18',
    'namespace::clean' => '0.23',
    'namespace::sweep' => '0.006'
  },
)->create_build_script;

exit 0;

__DATA__

sub _normalize_prereqs { # Dynamic config
   my $self = shift; my $p = $self->SUPER::_normalize_prereqs; return $p;
}
