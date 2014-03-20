use strict;
use warnings;

use Test::More tests=>18;

use lib '../lib';

my @tie_file_handle_split_exported = qw( TIEHANDLE PRINT PRINTF WRITE GETC READ READLINE EOF );

BEGIN {
	use_ok('FileHandle');
	use_ok('File::Temp');
	use_ok('Tie::FileHandle::Base');
	use_ok('Tie::FileHandle::Split');
}

can_ok( 'FileHandle', qw ( new ) );
can_ok( 'Tie::FileHandle::Split', @tie_file_handle_split_exported );

my $dir = File::Temp::tempdir( CLEANUP => 1 );
my $split_size = 512;

tie *TEST, 'Tie::FileHandle::Split', $dir, $split_size;

TEST->print( ' ' x ( $split_size - 1 ) ); my @files = (tied *TEST)->get_filenames();
is( scalar @files, 0, 'No files generated when output less than split_size.' );

TEST->print( ' ' x 1 ); @files = (tied *TEST)->get_filenames();
is( scalar @files, 1, 'First file generated at split_size.' );

TEST->print( ' ' x 1 ); @files = (tied *TEST)->get_filenames();
is( scalar @files, 1, 'No extra file 1B after split_size.' );

TEST->print( ' ' x ( $split_size - 2 ) ); @files = (tied *TEST)->get_filenames();
is( scalar @files, 1, 'No extra file at second split_size - 1 split_size.' );

TEST->print( ' ' x 1 ); @files = (tied *TEST)->get_filenames();
is( scalar @files, 2, 'Second file generated at split_size * 2.' );

(tied *TEST)->write_buffers(); @files = (tied *TEST)->get_filenames();
is( scalar @files, 2, 'No extra file generated when write_buffers is called on a file limit.' );

TEST->print( ' ' x ( $split_size - 1 ) ); @files = (tied *TEST)->get_filenames();
is( scalar @files, 2, 'No extra file generated after write_buffers at split_size - 1.' );

TEST->print( ' ' x 1 ); @files = (tied *TEST)->get_filenames();
is( scalar @files, 3, 'Third file generated after split_size * 3 after a call to write_buffers.' );

TEST->print( 'x' x 1 ); (tied *TEST)->write_buffers(); @files = (tied *TEST)->get_filenames();
is( scalar @files, 4, 'Fourth file generated after split_size * 3 + 1 calling write_buffers.' );

@files = (tied *TEST)->get_filenames();
is( -s $files[scalar @files - 1], 1, 'File generated from write_buffers on partial buffers are of correct size.' );

open( LAST_FILE, '<', $files[scalar @files - 1] ); my $last_file_content = <LAST_FILE>; close ( LAST_FILE );
is( $last_file_content, 'x', 'Check regression where incorrect buffer parts where output to split files.');

TEST->print( '0' x ( $split_size * 2 ) ); @files = (tied *TEST)->get_filenames();
is( scalar @files, 6, 'Fifth and sixth file generated from single print of split_size * 2.' );
