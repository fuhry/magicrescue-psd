#!/usr/bin/env perl

use strict;
use warnings;

use List::Util  qw/min max/;
use POSIX		qw/ceil/;

use Data::Dumper;

use constant	PSD_HEADER_MAGIC  => '8BPS';
use constant	PSD_HEADER_LENGTH => 4+2+6+2+4+4+2+2;
use constant	PSD_HEADER_PACK   => "a[4]nx[6]nNNnn";

unless (defined($ARGV[0])) {
	die "No output file specified";
}
open OUTPUT, "> $ARGV[0]" or die "Failed to open output file $ARGV[0]";

# Ordering:
#   1. Header (fixed length)
#   2. Color mode data
#   3. Image resources
#   4. Layer/mask info
#   5. Image data

sub read_psd_header {
	my $buf;
	read STDIN, $buf, PSD_HEADER_LENGTH;
	
	my ($magic, $version, $channels, $height, $width, $depth, $colormode) = unpack PSD_HEADER_PACK, $buf;
	
	exit (1) if $magic ne PSD_HEADER_MAGIC;
	
	print STDERR "PSD rescue: found magic: $magic\n";
	
	return {
		version   => $version,
		channels  => $channels,
		height    => $height,
		width     => $width,
		depth     => $depth,
		colormode => $colormode
	};
}

sub pack_psd_header {
	my ($version, $channels, $height, $width, $depth, $colormode) = @_;
	return pack(PSD_HEADER_PACK,
				PSD_HEADER_MAGIC,
				$version,
				$channels,
				$height,
				$width,
				$depth,
				$colormode);
}

sub read_u32be {
	my $buf;
	read STDIN, $buf, 4;
	my ($int) = unpack "N", $buf;
	return $int;
}

sub print_u32be {
	my ($int) = @_;
	print OUTPUT pack "N", $int;
}

sub read_u16be {
	my $buf;
	read STDIN, $buf, 2;
	my ($int) = unpack "n", $buf;
	return $int;
}

sub print_u16be {
	my ($int) = @_;
	print OUTPUT pack "n", $int;
}

sub read_section {
	my ($len) = @_;
	my $readcount = 0;
	my $buf;
	
	print_u32be $len;
	if ($len > 0) {
		while ($readcount < $len) {
			$readcount += read STDIN, $buf, min($len - $readcount, 8192);
			print OUTPUT $buf;
		}
	}
}

my $header = read_psd_header;

print STDERR "Found valid Photoshop image, $header->{'width'}x$header->{'height'}, $header->{'channels'} channels\n";

print OUTPUT pack_psd_header(
	$header->{'version'},
	$header->{'channels'},
	$header->{'height'},
	$header->{'width'},
	$header->{'depth'},
	$header->{'colormode'}
);

my $color_mode_data_len = read_u32be;
print STDERR "  - Length of color mode data: $color_mode_data_len bytes\n";
read_section $color_mode_data_len;

my $img_res_blocks_len = read_u32be;
print STDERR "  - Length of image resource data section: $img_res_blocks_len bytes\n";
read_section $img_res_blocks_len;

my $layer_mask_info_len = read_u32be;
print STDERR "  - Length of layer and mask info section: $layer_mask_info_len bytes\n";
read_section $layer_mask_info_len;

my $compression_type = read_u16be;
print_u16be $compression_type;

if ($compression_type == 0) {
	print STDERR "  - Image data format: RAW\n";
	my $bit_count = $header->{'channels'} * $header->{'height'} * $header->{'width'} * $header->{'depth'};
	my $byte_count = ceil $bit_count / 8;
	
	print STDERR "    -> $header->{'channels'} channels * $header->{'height'} rows * $header->{'width'} cols * $header->{'depth'} bpp = $bit_count bits\n";
	
	my $readcount = 0;
	my $buf;
	while ($readcount < $byte_count) {
		$readcount += read STDIN, $buf, min($byte_count - $readcount, 8192);
		print OUTPUT $buf;
	}
	
	print STDERR "  - Wrote $readcount bytes of image data\n";
}
elsif ($compression_type == 1) {
	print STDERR "  - Image data format: RLE\n";
	my $scanline_count = ($header->{'height'} * $header->{'channels'});
	print STDERR "    -> Scanline count: $scanline_count ($header->{'height'} rows * $header->{'channels'} channels)\n";
	my $scanline_byte_length = 0;
	for (my $i = 1; $i <= $scanline_count; $i++) {
		my $this_line = read_u16be;
		$scanline_byte_length += $this_line;
		print_u16be $this_line;
	}
	
	my $readcount = 0;
	my $buf;
	while ($readcount < $scanline_byte_length) {
		$readcount += read STDIN, $buf, min($scanline_byte_length - $readcount, 8192);
		print OUTPUT $buf;
	}
	
	print STDERR "  - Wrote $readcount bytes of image data\n";
}
else {
	print STDERR "Unsupported compression type $compression_type. Not attempting to read any further.\n";
}