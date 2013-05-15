# @(#)$Ident: 15io.t 2013-04-30 01:34 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.20.%d', q$Rev: 0 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use English qw(-no_match_vars);
use File::DataClass::IO;

isa_ok( io( $PROGRAM_NAME ), q(File::DataClass::IO) );

my $io; my $osname = lc $OSNAME;

sub p { join q(;), grep { not m{ \.svn }mx } @_ }
sub f { my $s = shift; $osname eq q(mswin32) and $s =~ s/\//\\/g; return $s }

subtest 'Deliberate errors' => sub {
   eval { io( 'quack' )->slurp };

   like $EVAL_ERROR, qr{ File \s+ \S+ \s+ cannot \s+ open }mx,
      'Cannot open file';

   eval { io( [ qw(non_existant file) ] )->println( 'x' ) };

   like $EVAL_ERROR, qr{ File \s+ \S+ \s+ cannot \s+ open }mx,
      'Cannot create file in non existant directory';

   eval { io( catdir( qw(t xxxxx) ) )->next };

   like $EVAL_ERROR, qr{ Directory \s+ \S+ \s+ cannot \s+ open }mx,
      'Cannot open directory';

   eval { io( 'qwerty' )->empty };

   like $EVAL_ERROR, qr{ Path \s+ \S+ \s+ not \s+ found }mx, 'No test empty';

   ok ! io( 'qwerty' )->exists, 'Non existant file';

   eval { io( 'qwerty' )->rmdir };

   like $EVAL_ERROR, qr{ Path \s+ \S+ \s+ not \s+ removed }mx,
      'Cannot remove non existant directory';
};

subtest 'Polymorphic Constructor' => sub {
   sub _filename { [ qw(t mydir file1) ] }

   ok io( catfile( qw(t mydir file1) ) )->exists, 'Constructs from path';
   ok io( [ qw(t mydir file1) ] )->exists, 'Constructs from arrayref';
   ok io( \&_filename )->exists, 'Constructs from coderef';
   ok io( { name => catfile( qw(t mydir file1) ) } )->exists,
      'Constructs from hashref';

   $io = io( [ qw(t mydir file1) ], q(r), oct q(400) ); $io = io( $io );

   ok $io->exists, 'Constructs from object';

   is( (sprintf "%o", $io->_perms & 07777), q(400),
       'Duplicates permissions from original object' );
};

subtest 'File::Spec::Functions' => sub {
   is( io( '././t/default.xml' )->canonpath, f( catfile( qw(t default.xml) ) ),
       'Canonpath' );
   is( io( '././t/bogus'       )->canonpath, f( catfile( qw(t bogus) ) ),
       'Bogus canonpath' );
   ok( io( catfile( q(), qw(foo bar) ) )->is_absolute, 'Is absolute' );

   my ($v, $d, $f) = io( catdir( qw(foo bar) ) )->splitpath;

   is( $d.q(x), catdir( q(foo), q(x) ), 'Splitpath directory' );
   is( $f, q(bar), 'Splitpath file' );

   my @dirs = io( catdir( qw(foo bar baz) ) )->splitdir;

   is scalar @dirs, 3, 'Splitdir count';
   is( (join q(+), @dirs), q(foo+bar+baz), 'Splitdir string' );
   is io( catdir( q(), qw(foo bar baz) ) )->abs2rel( catdir( q(), q(foo) ) ),
      f( catdir( qw(bar baz) ) ), 'Can abs2rel';
   is io( catdir( qw(foo bar baz) ) )->rel2abs( catdir( q(), q(moo) ) ),
      f( catdir( q(), qw(moo foo bar baz) ) ), 'Can rel2abs';
   is io()->dir( catdir( qw(doo foo) ) )->catdir( qw(goo hoo) ),
      f( catdir( qw(doo foo goo hoo) ) ), 'Catdir 1';
   is io()->dir->catdir( qw(goo hoo) ), f( catdir( qw(goo hoo) ) ), 'Catdir 2';
   is io()->catdir( qw(goo hoo) ), f( catdir( qw(goo hoo) ) ), 'Catdir 3';
   is io()->file( catdir( qw(doo foo) ) )->catfile( qw(goo hoo) ),
       f( catfile( qw(doo foo goo hoo) ) ), 'Catfile 1';
   is io()->file->catfile( qw(goo hoo) ), f( catfile( qw(goo hoo) ) ),
       'Catfile 2';
   is io()->catfile( qw(goo hoo) ), f( catfile( qw(goo hoo) ) ), 'Catfile 3';
   is io( [ qw(t mydir dir1) ] )->dirname, catdir( qw(t mydir) ), 'Dirname';
   ok io( [ qw(t mydir dir1) ] )->parent->is_dir, 'Parent';
};

subtest 'Absolute/relative pathname conversions' => sub {
   $io = io( $PROGRAM_NAME )->absolute;
   is "${io}", File::Spec->rel2abs( $PROGRAM_NAME ), 'Absolute';
   $io->relative;
   is "${io}", File::Spec->abs2rel( $PROGRAM_NAME ), 'Relative';
   ok io( q(t) )->absolute->next->is_absolute, 'Absolute directory paths';

   my $tmp = File::Spec->tmpdir;

   is io( $PROGRAM_NAME )->absolute( $tmp ),
      File::Spec->rel2abs( $PROGRAM_NAME, $tmp ), 'Absolute with base';
};

my ($device, $inode, $mode, $nlink, $uid, $gid, $device_id, $size,
    $atime, $mtime, $ctime, $blksize, $blocks) = stat( $PROGRAM_NAME );
my $stat = $io->stat;

subtest 'Retrieves inode status fields' => sub {
   is( $stat->{device},    $device,       'Stat device'      );
   is( $stat->{inode},     $inode,        'Stat inode'       );
   is( $stat->{mode},      $mode,         'Stat mode'        );
   is( $stat->{nlink},     $nlink,        'Stat nlink'       );
   is( $stat->{uid},       $uid,          'Stat uid'         );
   is( $stat->{gid},       $gid,          'Stat gid'         );
   is( $stat->{device_id}, $device_id,    'Stat device_id'   );
   is( $stat->{size},      $size,         'Stat size'        );
   ok( ($stat->{atime} ==  $atime)
    || ($stat->{atime} == ($atime + 1)),  'Stat access time' );
   is( $stat->{mtime},     $mtime,        'Stat modify time' );
   is( $stat->{ctime},     $ctime,        'Stat create time' );
   is( $stat->{blksize},   $blksize,      'Stat block size'  );
   is( $stat->{blocks},    $blocks,       'Stat blocks'      );
};

my $exp1 = 't/mydir/dir1;t/mydir/dir2;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp2 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir1/file1;t/mydir/dir2;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp3 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir1/dira/dirx;t/mydir/dir1/file1;t/mydir/dir2;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp4 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir1/dira/dirx;t/mydir/dir1/dira/dirx/file1;t/mydir/dir1/file1;t/mydir/dir2;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp_files1 = 't/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp_files2 = 't/mydir/dir1/file1;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp_files4 = 't/mydir/dir1/dira/dirx/file1;t/mydir/dir1/file1;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp_dirs1 = 't/mydir/dir1;t/mydir/dir2';
my $exp_dirs2 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir2';
my $exp_dirs3 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir1/dira/dirx;t/mydir/dir2';
my $exp_filt1 = 't/mydir/dir1/dira;t/mydir/dir1/dira/dirx';
my $exp_filt2 = 't/mydir/dir1/dira/dirx';

my $dir = catdir( qw(t mydir) );

subtest 'List all files and directories' => sub {
   is( p( io( $dir )->all       ), f( $exp1 ), 'All default'      );
   is( p( io( $dir )->all(1)    ), f( $exp1 ), 'All level 1'      );
   is( p( io( $dir )->all(2)    ), f( $exp2 ), 'All level 2'      );
   is( p( io( $dir )->all(3)    ), f( $exp3 ), 'All level 3'      );
   is( p( io( $dir )->all(4)    ), f( $exp4 ), 'All level 4'      );
   is( p( io( $dir )->all(5)    ), f( $exp4 ), 'All level 5'      );
   is( p( io( $dir )->all(0)    ), f( $exp4 ), 'All level 0'      );
   is( p( io( $dir )->deep->all ), f( $exp4 ), 'All default deep' );

   is( p( io( $dir )->all_files       ), f( $exp_files1 ), 'All files'      );
   is( p( io( $dir )->all_files(1)    ), f( $exp_files1 ), 'All files 1'    );
   is( p( io( $dir )->all_files(2)    ), f( $exp_files2 ), 'All files 2'    );
   is( p( io( $dir )->all_files(3)    ), f( $exp_files2 ), 'All files 3'    );
   is( p( io( $dir )->all_files(4)    ), f( $exp_files4 ), 'All files 4'    );
   is( p( io( $dir )->all_files(5)    ), f( $exp_files4 ), 'All files 5'    );
   is( p( io( $dir )->all_files(0)    ), f( $exp_files4 ), 'All files 0'    );
   is( p( io( $dir )->deep->all_files ), f( $exp_files4 ), 'All files deep' );

   is( p( io( $dir )->all_dirs       ), f( $exp_dirs1 ), 'All dirs'      );
   is( p( io( $dir )->all_dirs(1)    ), f( $exp_dirs1 ), 'All dirs 1'    );
   is( p( io( $dir )->all_dirs(2)    ), f( $exp_dirs2 ), 'All dirs 2'    );
   is( p( io( $dir )->all_dirs(3)    ), f( $exp_dirs3 ), 'All dirs 3'    );
   is( p( io( $dir )->all_dirs(4)    ), f( $exp_dirs3 ), 'All dirs 4'    );
   is( p( io( $dir )->all_dirs(5)    ), f( $exp_dirs3 ), 'All dirs 5'    );
   is( p( io( $dir )->all_dirs(0)    ), f( $exp_dirs3 ), 'All dirs 0'    );
   is( p( io( $dir )->deep->all_dirs ), f( $exp_dirs3 ), 'All dirs deep' );
};

subtest 'Filters matching patterns from directory listing' => sub {
   is p( io( $dir )->filter( sub { m{ dira }mx } )->deep->all_dirs ),
      f( $exp_filt1 ), 'Filter 1';
   is p( io( $dir )->filter( sub { m{ x }mx    } )->deep->all_dirs ),
      f( $exp_filt2 ), 'Filter 2';
};

subtest 'Chomp newlines and record separators' => sub {
   $io = io( $PROGRAM_NAME )->chomp; my $seen = 0;

   for ($io->slurp) { $seen = 1 if (m{ [\n] }mx) }

   ok ! $seen, 'Slurp chomps newlines'; $io->close; $seen = 0;

   for ($io->chomp->separator( 'io' )->getlines) { $seen = 1 if (m { io }mx) }

   ok ! $seen, 'Getlines chomps record separators';
};

subtest 'Create and remove a directory subtree' => sub {
   $dir = catdir( qw(t output subtree) );
   io( $dir )->mkpath; ok   -e $dir, 'Make path';
   $dir = catdir( qw(t output) );
   io( $dir )->rmtree; ok ! -e $dir, 'Remove tree';
   io( $dir )->mkdir;  ok   -e $dir, 'Make directory';
   io( $dir )->rmdir;  ok ! -e $dir, 'Remove directory';
};

subtest 'Setting assert creates path to file' => sub {
   $dir = catdir( qw(t output newpath ) );
   ok ! -e catfile( $dir, q(hello.txt) ), 'Non existant file';
   ok ! -e $dir, 'Non existant directory';
   $io = io( [ $dir, q(hello.txt) ] )->assert;
   ok ! -e $dir, 'Assert does not create directory';
   $io->println( 'Hello' );
   ok -d $dir, 'Writing file creates directory';
};

subtest 'Prints with and without newlines' => sub {
   $io = io( [ qw(t output print.t) ] );
   is $io->print( "one" )->print( "two" )->close->slurp, 'onetwo', 'Print 1';
   $io = io( [ qw(t output print.t) ] );
   is $io->print( "one\n" )->print( "two\n" )->close->slurp, "one\ntwo\n",
      'Print 2';
   $io = io( [ qw(t output print.t) ] );
   is $io->println( "one" )->println( "two" )->close->slurp, "one\ntwo\n",
      'Print 3';
};

subtest 'Create and detect empty subdirectories and files' => sub {
   $io = io( catdir( qw(t output empty) ) );
   ok $io->mkdir, 'Make a directory';
   ok $io->empty, 'The directory is empty';
   $io = io( catfile( qw(t output file) ) );
   ok $io->touch, 'Touch a file into existance';
   ok $io->empty, 'The file is empty';
};

# Tempfile/seek

my @lines = io( $PROGRAM_NAME )->chomp->slurp; my $temp = io( q(t) )->tempfile;

$temp->println( @lines ); $temp->seek( 0, 0 ); my $text = $temp->slurp || q();

ok length $text == $size,
   'Creates a tempfile seeks to the start and slurps content';

subtest 'Buffered reading/writing' => sub {
   my $outfile = catfile( qw(t output out.pm) );

   ok ! -f $outfile,   'Non existant output file';

   my $input   = io( [ qw(lib File DataClass IO.pm) ] )->open;

   ok ref $input,      'Open input';

   my $output  = io( $outfile )->open( q(w) );

   ok ref $output,     'Open output';

   if ($osname eq q(mswin32)) { $input->binary; $output->binary; }

   my $buffer; $input->buffer( $buffer ); $output->buffer( $buffer );

   ok defined $buffer, 'Define buffer';

   $output->write while ($input->read);

   ok !length $buffer, 'Empty buffer';
   ok $output->close,  'Close output';
   ok -s $outfile,     'Exists output file';
   ok $input->stat->{size} == $output->stat->{size}, 'File sizes match';
};

subtest 'Creates a file using atomic write' => sub {
   my $atomic_file = catfile( qw(t output B_atomic) );
   my $outfile     = catfile( qw(t output atomic) );

   $io = io( $outfile )->atomic->lock->println( 'x' );
   ok  -f $atomic_file, 'Atomic file exists';
   ok !-e $outfile,     'Atomic outfile does not exist'; $io->close;
   ok !-e $atomic_file, 'Renames atomic file';
   ok  -f $outfile,     'Writes atomic file';
};

# Substitution

$io = io( [ qw(t output substitute) ] );
$io->println( qw(line1 line2 line3) );
$io->substitute( q(line2), q(changed) );
is( ($io->chomp->getlines)[ 1 ], q(changed),
    'Substitutes one value for another' );

# Copy

my $to = io( [ qw(t output copy) ] ); $io->close;

$io->copy( $to ); is $io->all, $to->all, 'Copies a file';

SKIP: {
   ($osname eq q(mswin32) or $osname eq q(cygwin))
      and skip 'Unix permissions not applicable', 2;

   subtest 'Changes permissions of existing file' => sub {
      $io->chmod( 0777 ); $stat = $io->stat;
      is( (sprintf "%o", $stat->{mode} & 07777), q(777), 'Chmod 777' );
      $io->chmod( 0400 ); $stat = $io->stat;
      is( (sprintf "%o", $stat->{mode} & 07777), q(400), 'Chmod 400' );
   };

   subtest 'Creates files with specified permissions' => sub {
      my $path = catfile( qw(t output print.pl) );

      $io = io( $path, q(w), oct q(0400) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(400), 'Create 400' );
      $io->unlink;
      $io = io( $path, q(w), oct q(0440) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(440), 'Create 440' );
      $io->unlink;
      $io = io( $path, q(w), oct q(0600) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(600), 'Create 600' );
      $io->unlink;
      $io = io( $path, q(w), oct q(0640) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(640), 'Create 640' );
      $io->unlink;
      $io = io( $path, q(w), oct q(0644) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(644), 'Create 644' );
      $io->unlink;
      $io = io( $path, q(w), oct q(0664) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(664), 'Create 664' );
      $io->unlink;
      $io = io( $path, q(w), oct q(0666) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(666), 'Create 666' );
      $io->unlink;
      $io = io( $path )->perms( oct q(0640) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(640),
          'Create using prefered syntax' );
      $io->unlink;
   };
}

# Cleanup

io( catdir( qw(t output) ) )->rmtree;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End: