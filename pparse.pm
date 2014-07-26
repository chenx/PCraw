#!/usr/bin/perl -w
#
#1111111112222222222333333333344444444445555555555666666666677777777778888888888
#
# Part of Pcraw. To parse the html.
#
# @author: X. Chen
# @created on: 7/24/2014
# @last modified: 7/24/2014
#

######################################################
# Perldoc
######################################################

=head1 NAME 

PParse

=head1 DESCRIPTION

PParse is part of PCraw, but can also be used independently. 

PParse parses the contents of a html file, stores the extracted text 
(without tags) in an internal array @lines. This array can be printed 
to an output file by function outputText(), or be returned to the 
caller by function getLines(). The caller should first call function
init_params() to set up options.

=head1 SYNOPSIS

  use strict;
  use PParse;

  my $parser = new PParse;
  
  #
  # init_params(filename, log_mode);
  # filename: the name of the url file.
  # log_mode: 1 - output to file pparse_out.txt
  #           0 - do not output.
  #
  $parser->init_params($url, 1); 
  
  #
  # Here $contents is the html contents of the html file.
  # Parse result is stored in an array @lines.
  #
  $parser->parse($contents)->eof;
  
  #
  # Output @lines array to pparse_out.txt, if log_mode is 1.
  #
  $parser->outputText();
  
  #
  # Returns the @lines array.
  #
  my @lines = $parser->getLines();

=head1 LICENSE

APACHE/MIT/BSD/GPL

=head1 AUTHOR

=over 

=item 
X. Chen <chenx@hawaii.edu>

=item 
Copyright (c) since July, 2014

=back

=cut


use strict;

#
# Define PParse as a subclass of HTML::Parser.
#
package PParse;
use base "HTML::Parser";


######################################################
# Definition of global variables.
######################################################

my $DEBUG = 0;

my $OUTFILE = "pparse_out.txt";
my $log_outfile = 0;
my $filename = "File"; # name of the html file to parse.

#
# Store all the texts in this array.
# 
my @lines = ();


######################################################
# Definition of functions.
######################################################

#
# Initialize parameters.
#
sub init_params() {
  my ($self, $html_file, $log_mode) = @_;

  $filename = $html_file;
  
  if ($log_mode == 1) { $log_outfile = 1; }
  else { $log_outfile = 0; }
}


#
# Extract all texts, store in an array @lines.
# Only non-empty lines are stored.
#
sub text {
  my ($self, $text) = @_;
  
  # Must first trim, then chomp.
  $text = &trim( $text );
  chomp($text);
    
  if ($text ne "") { 
    if ($DEBUG) { print ": $text\n"; }
    push @lines, $text; 
  }  
}


#
# Write @lines array to output text.
#
sub outputText() {
  if ($log_outfile) {
    open FILE, ">> $OUTFILE" or die "Cannot write to output file $OUTFILE\n";
    print FILE "== $filename ==\n";
    foreach my $line (@lines) {
      print FILE "$line\n";
    }
    close FILE;
  }
}


#
# Return the @lines array to caller.
#
sub getLines() {
  return @lines;
}


#
# Utility functions.
#
sub ltrim { my $s = shift; $s =~ s/^\s+//; return $s; }
sub rtrim { my $s = shift; $s =~ s/\s+$//; return $s; }
sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s; }


1;



######################################################
# Change log
######################################################
# 7/24/2014
# First set up this module.
# So far only extracts text from html file and stores in a text file
# pparse_out.txt.
######################################################
