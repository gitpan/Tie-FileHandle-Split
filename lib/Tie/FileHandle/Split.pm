#!/usr/local/bin/perl

=head1 NAME

Tie::FileHandle::Split - Filehandle tie that captures, splits and stores output into files in a given path.

=head1 SYNOPSIS

# $path should exist or the current process have
# $size should be > 0
tie *HANDLE, 'Tie::FileHandle::Split', $path, $size;

(tied *HANDLE)->print( ' ' x $many_times_size );

# write all outstanding output from buffers to files
(tied *HANDLE)->write_buffers;

# get generated filenames to the moment
(tied *HANDLE)->get_filenames();

=head1 DESCRIPTION

This module, when tied to a filehandle, will capture and store all that
is output to that handle. You should then select a path to store files and a
size to split files.

=cut

package Tie::FileHandle::Split;

use strict;
use warnings;

use vars qw(@ISA $VERSION);
use base qw(Tie::FileHandle::Base);
$VERSION = 0.9;

use File::Temp;

# TIEHANDLE
# Usage: tie *HANDLE, 'Tie::FileHandle::Split'
sub TIEHANDLE {
	my ( $class, $path, $split_size ) = @_;

	my $self = {
		class => $class,
		path => $path,
		split_size => $split_size,
		buffer => '',
		buffer_size => 0,
		filenames => [],
	};

	bless $self, $class;
}

# Print to the selected handle
sub PRINT {
	my ( $self, $data ) = @_;
	$self->{buffer} .= $data;
	$self->{buffer_size} += length( $data );

	$self->_write_files( $self->{split_size} );
}

sub _write_files{
	my ( $self, $min_size ) = @_;

	my $written_chunks = 0;

	while ( $self->{buffer_size} - $min_size * $written_chunks >= $min_size ) {
		my ($fh, $filename) = File::Temp::tempfile( DIR => $self->{path} );


		# added complexity to work buffer with a cursor and doing a single buffer chomp
		$fh->print( substr $self->{buffer},$min_size * $written_chunks, $min_size * ++$written_chunks );
		$fh->close;

		push @{$self->{filenames}}, $filename;
	}
	if ( $written_chunks ) {
		$self->{buffer_size} -= $min_size * $written_chunks;
		if ( $self->{buffer_size} > 0 ) {
			$self->{buffer} = substr $self->{buffer}, -$self->{buffer_size} ;
		} else {
			$self->{buffer} = '';
		}
	}
}

=over 4

=item write_buffers

C<write_buffers> writes all outstanding buffers to files.
It is automatically called before destroying the object to ensure all data
written to the tied filehandle is written to files. If additional data is
written to the filehandle after a call to write_buffers a new file will be
created. On a standard file split operation it is called after writting all data
to the tied file handle ensure the last bit of data is written (in the most
common case where data size is not exactly divisible by the split size).

=back

=cut

sub write_buffers {
	# Must implement
	my ( $self ) = @_;

	# this should not happen...
	$self->_write_files( $self->{split_size} );
	if ( $self->{buffer_size} > 0 ) {
		$self->_write_files( $self->{buffer_size} );
	}
}

=over 4

=item get_filenames

C<get_filenames> returns a list of the files generates until the moment of the
call. It should be used to get the names of files and rename them to the
desired filenames. In a standard splitting operation C<get_filenames> is
called after outputting all data to the filehandle and calling C<write_buffers>.

=back

=cut

# Returns filenames generated up to the moment the method is called
sub get_filenames {
	my ( $self ) = @_;

	return @{$self->{filenames}} if defined $self->{filenames};
}

sub DESTROY {
	my ( $self ) = @_;

	$self->write_buffers() if ( $self->{buffer_size} > 0 );
}

1;

=head1 TODO

=over 4

=item * Very untested for anything other than writing to the filehandle.

=item * write_buffers should sync to disk to ensure data has been written.

=item * observer for newly created filenames.

=back

=head1 BUGS

No known bugs. Please report and suggest tests to gbarco@cpan.org.

=cut

=head1 AUTHORS AND COPYRIGHT

Written by Gonzalo Barco based on Tie::FileHandle::Buffer written by Robby Walker ( robwalker@cpan.org )

You may redistribute/modify/etc. this module under the same terms as Perl itself.

