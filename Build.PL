# @(#)$Ident: Build.PL 2013-12-15 14:31 pjf ;

use strict;
use warnings;

use Module::Build 0.4004;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver = 5.010001;
my $name     = 'File-DataClass'; $name =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'File::pushd' => '1.00',
    'Module::Build' => '0.4004',
    'Path::Tiny' => '0.013',
    'Test::Deep' => '0.108',
    'Test::Requires' => '0.06',
    'Text::Diff' => '1.37',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'CHI' => '0.58',
    'Cache::FastMmap' => '1.40',
    'Class::Method::ModifiersX::Augment' => '0.001',
    'Class::Null' => '2.101420',
    'File::Path' => '2.08',
    'Hash::Merge' => '0.12',
    'JSON' => '2.50',
    'Module::Runtime' => '0.013',
    'Moo' => '1.003',
    'MooX::ClassStash' => '0.005',
    'Try::Tiny' => '0.18',
    'Type::Tiny' => '0.030',
    'Unexpected' => 'v0.20.0',
    'namespace::clean' => '0.24',
    'namespace::sweep' => '0.006',
    'perl' => '5.010001'
  },
};

if ($] < $perl_ver) {
   $ENV{AUTOMATED_TESTING}
      or $ENV{PERL_CPAN_REPORTER_CONFIG}
      or $ENV{PERL5_CPANPLUS_IS_VERSION}
      or whimper "Minimum required Perl version is ${perl_ver}";
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{build_requires}->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
}

Module::Build->new(
  'module_name' => $name,
  'notes'       => { min_perl_version => $perl_ver },
  %{ $prereqs },

)->create_build_script;

exit 0;
