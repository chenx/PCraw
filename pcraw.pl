#!/usr/bin/perl -w
#
#1111111112222222222333333333344444444445555555555666666666677777777778888888888
#
# A web crawler written in Perl.
#
# Tested on: Windows, Linux, Mac.
#
# References:
# Short introduction to crawling in Perl:
#     http://www.cs.utk.edu/cs594ipm/perl/crawltut.html
# LWP: http://search.cpan.org/~gaas/libwww-perl-5.805/lib/LWP.pm
# HTTP::Response object: http://lwp.interglacial.com/ch03_05.htm
# HTTP status code:  http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
# HTML parser: http://search.cpan.org/dist/HTML-Parser/
# POSIX: http://search.cpan.org/~rgarcia/perl-5.10.0/ext/POSIX/POSIX.pod
# POSIX math functions, e.g., floor(), ceil():
#     http://www.perl.com/doc/FAQs/FAQ/oldfaq-html/Q4.13.html
# Progress bar: http://oreilly.com/pub/h/943
# Perldoc: http://juerd.nl/site.plp/perlpodtut
#          http://www.perlmonks.org/?node_id=252477
#
# @author: X. Chen
# @created on: 12/22/2007
# @last modified: 7/24/2014
#


######################################################
# Perldoc
######################################################

=head1 NAME 

PCraw

=head1 DESCRIPTION

PCraw is a perl script to crawl the web.

When used for the first time, it creates a local repository 
./download/ under the same directory. 
For each download task, a sub directory derived from the url_root 
(see below) will be created, and all downloads are stored there. 

A log file pcraw.log is created under the same directory.

A cookie file pcraw_cookie.txt is created under the same directory.

For each download task, at least one of these two parameters is needed:

1) url_root. Unless the global crawl option -g or --global-crawl
is specified, only files under this url will be downloaded.
This can be provided using the -r switch. If its value is not
provided, then it uses the longest path in url_start.

2) url_start. This is the url where the crawling starts from. 
If its value is not provided, it uses url_root as its value.
This can be provided using the -u switch.

=head1 SYNOPSIS

Usage: perl pcraw.pl [-cdefghilmoprsuvw]

For more help on usage, type: perl pcraw.pl -h 

=head1 LICENSE

APACHE/MIT/BSD/GPL

=head1 AUTHOR

=over 

=item 
X. Chen <chenx@hawaii.edu>

=item 
Copyright (C) since July, 2014

=back

=cut


######################################################
# Package name.
######################################################

package PCraw;


######################################################
# Include packages.
######################################################

use strict; 
use LWP::UserAgent;
use LWP::Protocol::http; # to remove TE header.
use HTTP::Cookies;
use HTTP::Request;
use HTTP::Response;
use HTML::LinkExtor;
use Time::Local;
use POSIX;        # For floor(), ceil().
use Encode;       # For decode_utf8, in parseLinks().
use IO::Handle;   # For flushing log file.
use Data::Dumper; # To print remote_headers in getUrl().
use PParse;       # To parse html.
$|++;             # For printing progress bar in getUrl().


######################################################
# Definition of global variables.
######################################################

my $DEBUG = 0;          # Print debug information.
my $browser;            # Browser, initialized at doCrawl() start.
my $local_repos = "./download/"; # Local storage repository directory.
my $local_root = "";    # Local root directory for a download task.
my $url_root = "";      # Only files under this root will be downloaded.
my $url_start = "";     # Where the crawling starts from.
my $url = "";           # File url.
my $contents;           # File contents
my %links_found;        # Hash to store links crawled.
my $links_found_ct = 0; # Counter for links found.
my @link_queue;         # Store links already crawled.
my $link_queue_pt = 0;  # pointer in $link_queue.
my $content_type;       # Content type of a file.
my $content_size;       # Content size of a file.
my $header_code;        # Response header code.
my @non_link_queue;     # Stores links that do not contain urls, e.g., images.
my $crawl_number = 0;   # Number of pages to crawl. 0 means infinite.
my $crawl_max_level = 0;# How deep in levels the crawl can go. 0 means ininite.
my $download_bytes;     # Total bytes of downloaded files.
my $file_min_size = 0;  # Min file size to download.
my $file_max_size = 0;  # Max file size to download. 0 means infinite.
my $crawl_interval = 5; # Wait (seconds) before crawling next html (doCrawl).
my $wait_interval = 1;  # Wait (seconds) before retrieving next url (getUrl).
my $flat_localpath = 0; # Use only one level of sub-directory locally.
my $use_agent_firefox = 1; # Simulate firefox browser in header
my $use_cookie = 1;     # Use cookie.
my $cookie_file = "pcraw_cookie.txt"; # Cookie file.
my $overwrite = 0;      # Overwrite previous download result.
my $global_crawl = 0;   # If 1, allow crawl outside $url_root.
my $referer_default = "http://yahoo.com"; # default referer visiting a page.
my $parse_html = 0;     # Parse html.

#
# To get download left time. Used in getUrl() and callback().
#
my $callback_t0; 

#
# If $verbose > 0, print more details to screen and log:
#   0x1 - print type/size and file download information.
#   0x2 - print reject/ignore file reason.
#
my $verbose = 0;
                        
#
# Some non-text files (such as images) are not under $url_root. 
# E.g., we want to download files in http://site/people/, 
# but the displayed images are stored in http://site/images/, 
# then set this to 1 if those should be downloaded also.
#
my $get_outside_file = 1;

#
# Dynamic pages are like: http://site/page.asp?a=b
# The feature is a "?" followed by parameters.
# If this is 1, only download static pages, and do not download dynamic pages.
#
my $static_page_only = 0;

#
# File mime types:
# text - 0x1
# image - 0x2
# audio - 0x4
# video - 0x8
# application - 0x10
# message - 0x20
# model - 0x40
# multipart - 0x80
# example - 0x100
# application/vnd - 0x200
# application/x - 0x400
#
# For a file whose mime type is M, download only when M & $download_type != 0.
# Default is to download all file types, user can change the default.
#
# Reference: 
# http://en.wikipedia.org/wiki/Internet_media_type
#
my $download_mime_type = 0xFFFFFFFF;

#
# For command line options.
#
my $OPT_URL_ROOT_S = "-r";
my $OPT_URL_ROOT_L = "--url-root";
my $OPT_URL_START_S = "-u";
my $OPT_START_URL_L = "--url-start";
my $OPT_HELP_S = "-h";
my $OPT_HELP_L = "--help";
my $OPT_CRAWL_NUMBER_S = "-n";
my $OPT_CRAWL_NUMBER_L = "--number-crawl";
my $OPT_STATIC_ONLY_S = "-s";
my $OPT_STATIC_ONLY_L = "--static-only";
my $OPT_OUTSIDE_FILE_S = "-i";
my $OPT_OUTSIDE_FILE_L = "--include-outside-file";
my $OPT_DEBUG_S = "-d";
my $OPT_DEBUG_L = "--debug";
my $OPT_VERSION_S = "-v";
my $OPT_VERSION_L = "--version";
my $OPT_VERBOSE_S = "-V";
my $OPT_VERBOSE_L = "--verbose";
my $OPT_MIME_TYPE_S = "-m";
my $OPT_MIME_TYPE_L = "--mime-type";
my $OPT_WAIT_INTERVAL_S = "-w";
my $OPT_WAIT_INTERVAL_L = "--wait";
my $OPT_CRAWL_INTERVAL_S = "-c";
my $OPT_CRAWL_INTERVAL_L = "--crawl-interval";
my $OPT_MIN_SIZE_L  = "--min-size";
my $OPT_MAX_SIZE_L  = "--max-size";
my $OPT_FLAT_PATH_S = "-f";
my $OPT_FLAT_PATH_L = "--flat-localpath";
my $OPT_OVERWRITE_S = "-o";
my $OPT_OVERWRITE_L = "--overwrite";
my $OPT_CRAWL_MAX_LEVEL_S = "-l";
my $OPT_CRAWL_MAX_LEVEL_L = "--level-crawl";
my $OPT_GLOBAL_CRAWL_S = "-g";
my $OPT_GLOBAL_CRAWL_L = "--global-crawl";
my $OPT_DEFAULT_REFERER_S = "-e";
my $OPT_DEFAULT_REFERER_L = "--referer-default";
my $OPT_PARSE_HTML_S = "-p";
my $OPT_PARSE_HTML_L = "--parse-html";

#
# Used by getUrl() to print a progress bar.
#
my $total_size; # Total size of a file to download.
my $final_data; # The content of a downloaded file.


######################################################
# Entry point of the program
######################################################

MAIN: if (1) {
  &getOptions();

  # In case you want to hard-code the urls, un-comment lines below.
  #$url_root = "http://";
  #$url_start = "http://";
  
  if ($url_root eq "" && $url_start eq "") {
    print ("\nError: url_root is not provided. Abort.\n");
    print ("For usage, type: perl $0 -h\n");
    exit(0);
  }
  
  if ($url_root eq "") { $url_root = &getUrlRootFromUrlStart(); }
  if (! ($url_root =~ /\/$/)) { $url_root .= "/"; } # url_root ends with "/".
  if ($url_root eq "$url_start/") { $url_start = "$url_start/"; }
  if ($url_start eq "") { $url_start = $url_root; }

  if (! ($url_start =~ m/^$url_root/i)) {
    print ("\nAbort: url_root must be a prefix of url_start\n");
    exit(0);
  }
  
  
  my $log = &getLogName();
  open LOGFILE, ">> $log";

  output ("");
  output ("===== Perl Web Crawler started =====");
  output ("url_root:  $url_root");
  output ("url_start: $url_start");
  output ("");
  &getSite();

  close LOGFILE;
}


1;


######################################################
# Definition of functions.
######################################################


#
# Use the longest possible path as root.
#
sub getUrlRootFromUrlStart() {
  my $f = &getUrlPath($url_start); 

  # This uses the domain name, too broad, so don't use this.
  #my $f = &getDomain($url_start);
  #$f = "http://$f/";
  #print "url_root: $f\n";

  return $f;
}

#
# from "http://a.com/b/c", get "a.com" and return.
#
sub getDomain() {
  my ($f) = @_;
  $f = &removeHttpHdr($f);
  my $index = index($f, "/");
  if ($index >= 0) {
    $f = substr($f, 0, $index);
  }  
  return $f;
}

#
# Get command line option switch values.
#
sub getOptions() {
  my $ARGV_LEN = @ARGV;
  my $state = "";

  for (my $i = 0; $i < $ARGV_LEN; ++ $i) {
    if ($DEBUG) { 
      print "argv[$i]. " . $ARGV[$i] . "\n";
    }

    my $a = $ARGV[$i];

    # Options followed with a value.
    if ($a eq $OPT_URL_ROOT_S || $a eq $OPT_URL_ROOT_L) {
      $state = $OPT_URL_ROOT_S; 
    }    
    elsif ($a eq $OPT_URL_START_S || $a eq $OPT_START_URL_L) {
      $state = $OPT_URL_START_S; 
    }
    elsif ($a eq $OPT_MIME_TYPE_S || $a eq $OPT_MIME_TYPE_L) {
      $state = $OPT_MIME_TYPE_S;
    }
    elsif ($a eq $OPT_WAIT_INTERVAL_S || $a eq $OPT_WAIT_INTERVAL_L) {
      $state = $OPT_WAIT_INTERVAL_S;
    }
    elsif ($a eq $OPT_CRAWL_INTERVAL_S || $a eq $OPT_CRAWL_INTERVAL_L) {
      $state = $OPT_CRAWL_INTERVAL_S;
    }
    elsif ($a eq $OPT_CRAWL_MAX_LEVEL_S || $a eq $OPT_CRAWL_MAX_LEVEL_L) {
      $state = $OPT_CRAWL_MAX_LEVEL_S;
    }
    elsif ($a eq $OPT_DEFAULT_REFERER_S || $a eq $OPT_DEFAULT_REFERER_L) {
      $state = $OPT_DEFAULT_REFERER_S;
    }
    elsif ($a eq $OPT_OUTSIDE_FILE_S || $a eq $OPT_OUTSIDE_FILE_L) {
      $state = $OPT_OUTSIDE_FILE_S;
    }
    elsif ($a eq $OPT_VERBOSE_S || $a eq $OPT_VERBOSE_L) {
      $verbose = 2; # default verbase level is 2, if no value provided.
      $state = $OPT_VERBOSE_S;
    }
    elsif ($a eq $OPT_MIN_SIZE_L) {
      $state = $OPT_MIN_SIZE_L;
    }
    elsif ($a eq $OPT_MAX_SIZE_L) {
      $state = $OPT_MAX_SIZE_L;
    }
    
    # Options whose value is on/off, and do not follow with a value.
    elsif ($a eq $OPT_CRAWL_NUMBER_S || $a eq $OPT_CRAWL_NUMBER_L) {
      $crawl_number = 1; $state = $OPT_CRAWL_NUMBER_S; 
    }    
    elsif ($a eq $OPT_STATIC_ONLY_S || $a eq $OPT_STATIC_ONLY_L) {
      $static_page_only = 1; $state = ""; 
    }    
    elsif ($a eq $OPT_DEBUG_S || $a eq $OPT_DEBUG_L) {
      $DEBUG = 1; $state = ""; 
    }
    elsif ($a eq $OPT_FLAT_PATH_S || $a eq $OPT_FLAT_PATH_L) {
      $flat_localpath = 1; $state = "";
    }
    elsif ($a eq $OPT_OVERWRITE_S || $a eq $OPT_OVERWRITE_L) {
      $overwrite = 1; $state = "";
    }
    elsif ($a eq $OPT_GLOBAL_CRAWL_S || $a eq $OPT_GLOBAL_CRAWL_L) {
      $global_crawl = 1; $state = "";
    }
    elsif ($a eq $OPT_PARSE_HTML_S || $a eq $OPT_PARSE_HTML_L) {
      $parse_html = 1; $state = "";
    }

    # Options that cause the program to display a message and exit.
    elsif ($a eq $OPT_VERSION_S || $a eq $OPT_VERSION_L) {
      &showVersion(); exit(0); 
    }
    elsif ($a eq $OPT_HELP_S || $a eq $OPT_HELP_L) {
      &showUsage(); exit(0); 
    }

    # Get values for options with a value.
    elsif ($state eq $OPT_URL_ROOT_S) {
      $url_root = $a; $state = ""; 
    }
    elsif ($state eq $OPT_URL_START_S) {
      $url_start = $a; $state = ""; 
    }
    elsif ($state eq $OPT_CRAWL_NUMBER_S) { # max links to crawl.
      $crawl_number = getPosInt($a); $state = ""; 
    }
    elsif ($state eq $OPT_MIME_TYPE_S) {
      $download_mime_type = getPosInt($a); $state = "";
    }
    elsif ($state eq $OPT_WAIT_INTERVAL_S) {
      $wait_interval = getPosInt($a); $state = "";
    }
    elsif ($state eq $OPT_CRAWL_INTERVAL_S) {
      $crawl_interval = getPosInt($a); $state = "";
    }
    elsif ($state eq $OPT_MIN_SIZE_L) {
      $file_min_size = getPosInt($a); $state = "";    
    }
    elsif ($state eq $OPT_MAX_SIZE_L) {
      $file_max_size = getPosInt($a); $state = "";    
    }
    elsif ($state eq $OPT_CRAWL_MAX_LEVEL_S) {
      $crawl_max_level = getPosInt($a); $state = "";
    }
    elsif ($state eq $OPT_DEFAULT_REFERER_S) {
      $referer_default = $a; $state = "";
    }
    elsif ($state eq $OPT_VERBOSE_S) {
      $verbose = getPosInt($a); $state = "";
    }
    elsif ($state eq $OPT_OUTSIDE_FILE_S) {
      $get_outside_file = getPosInt($a); $state = "";
    }

    else { 
      print "Warning: unknown option $a\n";
      $state = ""; 
    }
  }
}


#
# Convert a string to a positive integer.
#
sub getPosInt() {
  my ($n) = @_;
  $n = 0 + $n; # convert string to integer.
  if ($n < 0) { $n = 0; }
  return $n;
}


#
# Help message of this program.
#
sub showUsage() {
  my $usage = <<"END_USAGE"; 

Usage: perl $0 $OPT_URL_START_S <url_start> [$OPT_URL_ROOT_S <url_root>] [-cdefghilmoprsuvw]

  Options (short format):
    -c: wait time (seconds) before crawling next html page.
    -d: debug, print debug information.
    -e: default referer when crawling a url, if none exists.
        This is used when crawling the first page, when no referer exists yet.
    -f: use flat local path: only one level under local root.
    -g: allow global crawl outside url_root.
    -h: print this help message.
    -i: download non-text files outside the url_root. Value is on(1)/off(0). Default is on.
        Used when some linked files are stored outside the url_root.
    -l: max levels to crawl. Default to 0, 0 means inifinite.
    -m: file mime type. Only files with given mime types are downloaded.
        text - 0x1
        image - 0x2
        audio - 0x4
        video - 0x8
        application - 0x10
        message - 0x20
        model - 0x40
        multipart - 0x80
        example - 0x100
        application/vnd - 0x200
        application/x - 0x400
        Refer to: http://en.wikipedia.org/wiki/Internet_media_type
    -n <number_of_links>: the number of links to crawl. 0 means inifinite.
    -o: overwrite previous download result.
    -p: parse html. So far just print out text without tags.
    -r <url_root>: root url.
        Only files under this path are downloaded. Except when -o is used.
    -s: only download static pages. 
        Dynamic pages with parameters like http://a.php?a=b are ignored.
    -u <url_start>: start url.
        This is where a crawling task starts from.
    -v: show version information.
    -w: wait time (seconds) before getting next url. Difference of this 
        with -c is: on each html page, there can be several urls. -c is
        for each html page, -w is for each url.

  Options (long format):
    --debug: same as -d
    --flat-localpath: same as -f
    --global-crawl: same as -g
    --help: same as -h
    --inculde-outside-file: same as -i
    --level-crawl: same as -l
    --mime_type: same as -m
    --min-size: min file size to download, in bytes.
    --max-size: max file size to download, in bytes. 0 means infinite.
    --number-crawl: same as -t
    --overwrite: same as -o
    --parse-html: same as -p
    --referer-default: same as -e
    --static-only: same as -s
    --url-root: same as -r
    --url_start: same as -u
    --version: same as -v
    --wait: same as -w

  The two most important options are:
  -r or --url-root : url_root is needed, if not provided, use longest path of url_start.
  -u or --url-start: url_start, if not provided, use url_root as default.

  At least one of these two must be provided.
  
  If an url contains special characters, like space or '&', then
  it should be enclosed with double quotes to work.

  To see perldoc document, type: perldoc $0
  
  Examples:
    perl $0 -h
    perl $0 -r http://a.com 
    perl $0 -u http://a.com/index.html
    perl $0 -r http://a.com -u http://a.com/about.html
    perl $0 --url-root http://a.com 
    perl $0 --url-root http://a.com --url-start http://a.com/
    perl $0 --url-root http://a.com -n 1 -m 2 -f --min-size 30000
  
END_USAGE

  print $usage;
}


#
# Version information of this program.
#
sub showVersion() {
  print "\nPcraw version 1.0. \nCopyright (C) 2014, X. Chen\n\n";
}


#
# Log file name is obtained by
# replacing the ".pl" suffix with ".log".
#
sub getLogName() {
  my $log = $0;
  if ($log =~ /\.pl/i) { $log =~ s/\.pl/\.log/i; }
  else { $log .= ".pl"; }
  return $log;
}

sub getLnkFoundLog() { 
  return "$local_root/.pcraw_lnk_found.log"; 
}

sub getLnkQueueLog() { 
  return "$local_root/.pcraw_" . getQueueLogName() . "_lnk_Q.log"; 
}

sub getLnkQueueIndexLog() { 
  my $name = $url_start;
  $name =~ s/^$url_root//;
  $name = encodePath($name);
  return "$local_root/.pcraw_" . getQueueLogName() . "_lnk_Q_ID.log"; 
}

sub getLastUrlStartLog() {
  return "$local_root/.pcraw_last_url_start.log";
}


#
# Get a name specific to each url_start.
#
sub getQueueLogName() {
  my $name = $url_start;
  $name =~ s/^$url_root//;
  $name = encodePath($name);
  $name =~ s/[\/\.]/_/g; # replace all "/" and "." with "_".
  return $name;    
}

#
# Create local repository.
#
sub createLocalRepos() {
  if (! (-d $local_repos)) { 
    if (! &createPath($local_repos)) {
      output("Cannot create local repository: $local_repos");
      die(); 
    }
    output ("Local repository $local_repos is created");
  }
}


#
# Local_root derives from url_root.
#
sub getLocalRoot() {
  my ($root) = @_;
  if ($DEBUG) { output ("getLocalRoot(): root = $root" ); }
  
  $root = &removeHttpHdr($root);
  if ($root =~ /\/$/) { $root =~ s/\/$//; } # remove trailing "/" if any.
  
  $root =~ s/\//_/g; # replace all "/" with "_".
  $root = encodePath($root);

  $local_root = $local_repos . $root;
  if ($DEBUG) 
  { 
    output ("getLocalRoot(): local_root = $root" ); 
  }
}


#
# Remove "http://" or "https://" from head of string.
#
sub removeHttpHdr() {
  my ($s) = @_;
  if ($s =~ /^http:\/\//i) { $s =~ s/^http:\/\///i; }
  elsif ($s =~ /^https:\/\//i) { $s =~ s/^https:\/\///i; }
  return $s;
}

#
# Start to crawl from the url_start website.
# 
sub getSite() {
  my ($ss_s, $mm_s, $hh_s) = localtime(time);

  &createLocalRepos(); # create local repository, if not exist.
  &getLocalRoot($url_root); # create local root for this task.
  
  if ($overwrite && -d $local_root) { clearHistory(); }

  if (! (-d $local_root)) { 
    if (! &createPath($local_root)) {
      output("Abort. Cannot create local root: $local_root");
      return; # return instead of die(), to close LOGFILE handle.
    }
    output ("Local root $local_root is created");
    output ("");
  }
  
  my $history_exist = &getHistory();
  
  &logLastUrlStart(); # log which url_start this run uses.
  open LOG_Lnk_Found, ">> " . &getLnkFoundLog();
  open LOG_Lnk_Queue, ">> " . &getLnkQueueLog();
  #open LOG_Lnk_Queue_Index, "> " . &getLnkQueueIndexLog();

  if (! $history_exist) {
    #print "::$url_start\n";
    @link_queue = (@link_queue, $url_start);
    @non_link_queue = ();
    $links_found{$url_start} = -1;
    $links_found_ct = 1;
    &logLnkFound("1. $url_start => $links_found{$url_start}");
    &logLnkQueue("1. $url_start");
    $link_queue_pt = 0;
  }

  &doCrawl();
  
  #close LOG_Lnk_Queue_Index;
  close LOG_Lnk_Queue;
  close LOG_Lnk_Found;
  
  my ($ss_t, $mm_t, $hh_t) = localtime(time);
  my $sec = ($hh_t - $hh_s) * 3600 + ($mm_t - $mm_s) * 60 + ($ss_t - $ss_s);
  output ("Total time spent: " . &writeTime($sec) );
}


#
# Overwrite crawl history.
# Now do this by moving the previous directory to dir_(k), k = 2, 3, ...
#
sub clearHistory() {
  if (-d $local_root) {
    #printf "rm -rf $local_root\n";
    execCmd("mv $local_root " . &resolveConflictDirName($local_root));
  }
}


#
# Read log, resume from breaking point, instead of crawl again.
#
sub getHistory() {
  my $file = &getLnkFoundLog();
  if (! (-e $file)) { return 0; }
  open FILE, "< $file" or die "getHistory(): cannot read file $file";
  while(<FILE>) {
    chomp();
    #print "$_\n";
    if (m/(\d+)\.\s(.+)\s=\>\s([-]?\d+)/) {
      #print "$2 ... $3\n";
      $links_found{$2} = $3;
      #print "links_found{$2} = $3;\n";
    }
  }
  close FILE;
  my @keys = keys %links_found;
  $links_found_ct = @keys;
  
  #&dumpHash(\%links_found); print "--------------\n";

  $file = &getLnkQueueLog();
  if (! (-e $file)) {
    #print "not exist: $file\n";
    return 0;
  }
  # otherwise, initialize history.
  
  # link_queue
  $file = &getLnkQueueLog();
  open FILE, "< $file" or die "getHistory(): cannot read file $file";
  while(<FILE>) {
    chomp();
    #print "$_\n";
    if (m/(\d+)\.\s(.+)/) {
      #print "$2\n";
      @link_queue = (@link_queue, $2);
    }
  }
  close FILE;
  
  # link_queue_pt
  $file = &getLnkQueueIndexLog();
  if (! -e $file) {
    $link_queue_pt = 0;
    return 1;
  }

  open FILE, "< $file" or die "getHistory(): cannot read file $file";
  while(<FILE>) {
    chomp();
    #print "$_\n";
    $link_queue_pt = $_;
  }
  close FILE;
  
  @non_link_queue = ();
  
  return 1;
}


sub dumpHash() {
  my $h = shift;
  my %hash = %$h;
  my @keys = keys %hash;
  my $i = 0;
  foreach my $key (@keys) {
    ++ $i;
    print "$i. $key => $hash{$key}\n";
  }
}


sub getBrowser() {
  push(@LWP::Protocol::http::EXTRA_SOCK_OPTS, SendTE=>0);
  my $browser = LWP::UserAgent->new(keep_alive=>1);
  $browser->timeout(10);
    
  # Use cookie.
  # perl pcraw.pl -r http://10.24.7.16 -u http://10.24.7.16:9000/test
  if ($use_cookie) {
    my $cookie_jar = HTTP::Cookies->new(
      file => "$cookie_file",
      autosave => 1,
      ignore_discard => 1,
    );
    $browser->cookie_jar( $cookie_jar );
  }
  #$browser->cookie_jar->clear();
  #$browser->cookie_jar(HTTP::Cookies->new(hide_cookie2 => 1));

  # Simulate Firefox Agent.
  if ($use_agent_firefox) {
    $browser->default_headers(HTTP::Headers->new(
      'User-Agent' => 'Mozilla/5.0 (Windows NT 5.1; rv:30.0) Gecko/20100101 Firefox/30.0',
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      #'Accept' => '*/*',
      'Accept-Language' => 'en-US,en;q=0.5',
      #'Accept-Encoding' => 'gzip, deflate',
      #Connection => 'keep-alive',
      #'keep-alive' => '1',
    ));
    #$browser->headers()->remove_header('Connection');
  } 
  
  return $browser; 
}

#
# Crawl the site, using BFS with a queue. Procedure is:
#
# foreach $url in @link_queue {
#   download $url;
#   $content := contents of $url;
#   @urls := all urls in $content;
#   foreach $link in @urls {
#     if (file $link is of text type, i.e., may contain links) {
#       add $link to @link_queue;
#     }
#     else {
#       add $link to @non_link_queue;
#       download $link;
#     }        
#     if ($link not in %links_found) { add $link to %links_vsiited; }
#   }
# }
#
# Note: 
# 1) A file is saved only when its mime type is wanted.
#    For text files, even if mime type is not wanted, the 
#    contents have to be crawled to retrieve links.
# 2) text/html files, when first found, inserted to %links_found
#    but value is negative, which means they are found but not crawled
#    yet. When they are crawled, their value is changed to positive.
#    This make crawl starting from different url_start manageable.
# 3) In the log files _found.log and _lnk_Q.log, the numbering 
#    is actually useless. 
#
sub doCrawl() {
  my $link_queue_len = @link_queue; 
  my $resource_download_ct = 0;
  my %referers;
  $browser = getBrowser();
  $download_bytes = 0;  # Initialize total download size.
  
  while ($link_queue_pt < $link_queue_len) {
    # For testing, only get first $crawl_number number of links.
    if ($crawl_number > 0 && $link_queue_pt >= $crawl_number) { last; } 
    print ("wait for $crawl_interval seconds ...                   \r");
    sleep($crawl_interval);
    print ("                        \r"); # clear the previous message.

    $url = $link_queue[$link_queue_pt];     # get next url to crawl.    
    my $cur_url_value = $links_found{$url}; # should alwasy exist and < 0.
    if ($cur_url_value < 0) { 
      $cur_url_value = - $cur_url_value;       
      $links_found{$url} = - $links_found{$url};
    }    
    
    # Do not crawl more than max levels.
    if ($crawl_max_level > 0 && ($cur_url_value > $crawl_max_level)) { last; }
        
    # Otherwise, continue crawl.
    output( "link #" . (1 + $link_queue_pt) . ": $url" );

    # No longer get content type/size at the beginning of getUrl(), to save
    # one head request per file. Anyways, type is always "text/html" here,
    # and the file is always downloaded no matter what the size is.
    $content_size = -1;
    $content_type = "text/html";
    $contents = &getUrl($url, $browser, $referers{$url} // $referer_default);
    my $content_len = length($contents); 
    
    if ($content_len <= 0) { # if == 0, then may be "403 Access Forbidden".
      $link_queue_pt ++;
      &logLnkQueueIndex($link_queue_pt);
      next;
    }

    if (&mimeTypeMatch("text") && &fileSizeMatch($content_len)) {
      &saveContent($url, $contents, $content_type, $content_len);
    }
   
    if ($parse_html) { &parseHtml($url, $contents); } # Parse html.
   
    print "parsing links, please wait..\r";
    my @new_urls = &parseLinks($url, $contents);

    foreach my $new_url (@new_urls) {
      # Remove link anchor like in "http://a.com/a.html#section_1".
      if ($new_url =~ /\#[a-z0-9\-\_\%\.]*$/i) { 
        $new_url =~ s/\#[a-z0-9\-\_\%\.]*$//i;
      }

      # isWantedFile() calls getFileHeader(), and gets type/size for wanted files.
      my $isWanted = isWantedFile($new_url, $url);
      if ( $isWanted == 1 ) {
        #print "::$new_url, $content_type, $content_size\n"; 
        if ($content_type =~ /text\/html/i || $content_type eq "") {
          if (! exists($links_found{$new_url})) {
            #print "add to link Q: $new_url, type: $content_type\n";
            @link_queue = (@link_queue, $new_url);
          
            $link_queue_len ++; #= @link_queue;
            logLnkQueue("$link_queue_len. $new_url");
            $referers{$new_url} = $url; # record referer of page $new_url.

            # add found new_url with level, label as not crawled.
            $links_found{$new_url} = - ( $cur_url_value + 1 );
            $links_found_ct ++;
            &logLnkFound("$links_found_ct. $new_url => $links_found{$new_url}");            
          }
        }
        else {
          if (! &mimeTypeMatch($content_type)) { # from getFileHeader().
            if ($verbose & 2) { print "* ignore (type_mismatch): $new_url\n"; }    
          }
          elsif (! &fileSizeMatch($content_size)) { # from getFileHeader().
            if ($verbose & 2) { print "* ignore (size_mismatch): $new_url\n"; }    
          }
          else {
            #print "add to non-link Q, and save: $new_url\n";
            $resource_download_ct += 1;
            output ("file #$resource_download_ct: $new_url");
            @non_link_queue = (@non_link_queue, $new_url);
            my $content = &getUrl($new_url, $browser, $url);            
            my $content_len = length($content);
            &saveContent($new_url, $content, $content_type, $content_len);
          }
        }
      }
      else {
        #print "::$new_url, $content_type, $content_size\n";
        if ($verbose & 2) { # && $content_type =~ /text\/html/i) {
          print "* reject (" . getRejectReason($isWanted) . "): $new_url\n";
        }
      }
      
      #print "::$new_url:: $links_found{$new_url}\n";
      if (! exists($links_found{$new_url})) {
        $links_found{$new_url} = $cur_url_value + 1; # record crawl level.
        if ($content_type =~ /text\/html/i) { # html files should keep crawlable.
          $links_found{$new_url} = - $links_found{$new_url}; 
        }
        $links_found_ct ++;
        &logLnkFound("$links_found_ct. $new_url => $links_found{$new_url}");
      }
    } # end of foreach.
    
    # Set this url as crawled. Do this at this end, so won't lose work. 
    # If program crashes before this, next re-run will pick up this page.
    &logLnkFound("$links_found_ct. $url => $links_found{$url}");            

    $link_queue_len = @link_queue;
    $link_queue_pt ++;
    &logLnkQueueIndex($link_queue_pt);
  } # end of while.
    
  &clearProgressBar();
  #&dumpLinksCrawled($link_queue_pt);
  &writeSummary($link_queue_pt);
}


#
# For development/debug use only.
#
sub dumpLinksCrawled() {
  my ($link_queue_pt) = @_;
  print "\n\n== Links found (link => depth) ==\n";
  my @keys = keys %links_found;
  my $len = @keys;
  for (my $i = 1; $i <= $len; ++ $i) {
    my $key = $keys[$i-1];
    print "$i. $key => " . $links_found{$key} . "\n";
  }
    
  print "\n== links crawlable ==\n";
  $len = @link_queue;
  for (my $i = 1; $i <= $len; ++ $i) {
    print "$i. $link_queue[$i - 1]\n";
  }
  print "== current pointer: $link_queue_pt\n";
}


#
# Write download summary.
#
sub writeSummary() {
  my ($link_queue_pt) =@_;
  my $link_queue_len = @link_queue;
  my $non_link_file_ct = @non_link_queue;
  
  my @keys = keys %links_found;
  my $links_found = @keys;

  output ("");
  output ("Links found: $links_found");
  output ("Links crawlable: $link_queue_len");
  output ("Links crawled (A): $link_queue_pt");
  output ("Other files downloaded (B): $non_link_file_ct");
  output ("Total files downloaded (A+B): " . ($link_queue_pt + $non_link_file_ct));
  output ("Total download size: $download_bytes bytes, or " 
          . getDownloadSize());
}


sub getDownloadSize() {
  my $size;
  if ($download_bytes < 1000000) { # less than 1 MB.
    $size = sprintf("%.3f", $download_bytes/1024) . " KB";
  }
  elsif ($download_bytes < 1000000000) { # less than 1 GB.
    $size = sprintf("%.3f", $download_bytes/1024/1024) . " MB";
  }
  else {
    $size = sprintf("%.3f", $download_bytes/1024/1024/1024) . " GB";
  }
  return $size;
}


sub writeTime() {
  my ($sec) = @_;
  my ($h, $m, $s);

  $h = floor($sec / 3600);
  if ($h < 10) { $h = "0$h"; }

  $m = floor(($sec - ($h * 3600)) / 60);
  if ($m < 10) { $m = "0$m"; }

  $s = $sec - ($h * 3600) - ($m * 60);
  if ($s < 10) { $s = "0$s"; }

  return "$h:$m:$s";
}


#
# Get html content of an url.
# This works, but does not use a call_back to draw progress bar.
#
# To call, first initiate the $browser variable:
#   my $browser = LWP::UserAgent->new();
#   $browser->timeout(10);
# Then call this function with: getUrl($url, $browser).
#
# $response->content_type() can be:
# text/html, image/jpeg, image/gif, application/msword etc.
#
#sub getUrl_deprecated() {
#  my ($url, $browser) = @_;
#  my $request = HTTP::Request->new(GET => $url);
#  my $response = $browser->request($request);
#  if ($response->is_error()) {
#    output( "getUrl error: " . $response->status_line . " -> URL: " . $url);
#    return "";
#  }
#  #print "$url: content type: " . $response->content_type() . "\n";
#  return $response->content();
#}


#
# Get html content of an url.
# $content_size is obtained from getFileHeader(),
# instead of getting it again here. This saves 1 request per page.
#
sub getUrl() {
  sleep($wait_interval); # Be nice, wait before each request.
  
  my ($url, $browser, $referer) = @_;
  $final_data = "";
   
  $total_size = $content_size // -1;
  #print "getUrl(): size: $total_size\n";
  
  $callback_t0 = time(); # Download start time.
  # now do the downloading.
  my $request = new HTTP::Request('GET', "$url");
  if ($referer ne "") { $request->referer("$referer"); }
  my $response = $browser->request($request, \&callback, 8192);

  # Replaced with the code above using referer.
  #my $response = $browser->get($url, ':content_cb' => \&callback );
  
  # Don't clear row here, it's too soon. Clear in function doCrawl().
  #print progressBar(-1,01,25,'='); 
  
  # Keep the progress bar, if desired.
  #if (($verbose & 1) && $total_size ne -1) { print "\n"; } 
  return $final_data; # File content.
}


#
# Call per chunk. To update progress bar.
#
sub callback {
   my ($data, $response, $protocol) = @_;
   $final_data .= $data;
   #print "callback: len = " . length($final_data) . "\n";
   
   my $time_left = 0;
   my $t_used = time() - $callback_t0; # Time used so far.
   if ($t_used > 0) {
     my $cur_size = length($final_data);
     $time_left = (($total_size - $cur_size) / $cur_size) * $t_used;
   }
   print progressBar( length($final_data), $total_size, 25, '=', $time_left ); 
}


#
# Print progress bar.
# Each time sprintf is printing to the same address, so same location on screen.
# $got - bytes received so far.
# $total - total bytes of the file.
# $width - size of the progress bar: "==..==>"
# $char  - the '=' char used by the progress bar.
#
# Code is modified from: http://oreilly.com/pub/h/943
#
# wget-style. routine by tachyon
# at http://tachyon.perlmonk.org/
#
sub progressBar {
  my ( $got, $total, $width, $char, $time_left ) = @_;
  $width ||= 25; $char ||= '-'; # "||=": default to if not defined.
  $time_left ||= 0;

  # Some web servers don't give "content-length" field.
  # In such case don't print progress bar.
  if ($total == -1) { return; }

  my $num_width = length ($total);

  #print "got = $got, total = $total\n";    
  if ($got == -1) { 
    # removes the previous print out. 
    # 79 is used since in standard console, 1 line has 80 chars.
    # 79 spaces plus a "\r" is 80 chars.
    # Besides, this should be enough to cover reasonable file sizes.
    # e.g. the progress bar below has 64 chars, when file size is 6-digit.
    # |========================>| Got 100592 bytes of 100592 (100.00%)
    # So 12 chars are used for file size, 52 chars for the rest bytes.
    # This gives 79 - 52 = 27 bytes for file size, so file size
    # can be up to 13 digits without interrupting the format.
    sprintf (' ' x 79) . "\r";  
  }
  else {
    sprintf 
      "|%-${width}s| Got %${num_width}s bytes of %s (%.2f%%, %.1fsec)   \r", 
      $char x (($width-1)*$got/$total). '>', 
      $got, $total, 100*$got/+$total,
      $time_left;
  }
}


#
# clear left over chars of current row from prevous progress bar.
#
sub clearProgressBar() {
  print progressBar(-1, 0, 0, ''); 
}


#
# Parse html.
# See: http://www.foo.be/docs/tpj/issues/vol5_1/tpj0501-0003.html
# Implmentation is in pparse.pm.
#
sub parseHtml() { 
  my ($url, $contents) = @_;

  my $parser = new PParse;
  $parser->init_params($url, 1); 
  $parser->parse($contents)->eof;
  $parser->outputText();
  #my @lines = $parser->getLines();
}

#
# Note that LinkExtor parses both <a> and <img>.
#
# $$link[i]: valid values for i: 0 (tag name), 1(attribute name), 2(link value)
# e.g.: <img src='http://127.0.0.1/index.html'>
# Here $$link[0] = img, $$link[1] = src, $$link[2] = http://127.0.0.1/index.html
#
sub parseLinks() {
  my ($url, $contents) = @_;
  my ($page_parser) = HTML::LinkExtor->new(undef, $url);

  $contents = &getCustomLinks($contents);

  # This would have the warning:
  # "Parsing of undecoded UTF-8 will give garbage when decoding entities".
  # So use the one with decode_utf8, about same speed.
  #$page_parser->parse($contents)->eof; 
  $page_parser->parse(decode_utf8 $contents)->eof;   
  
  my @links = $page_parser->links;
  my @urls;

  foreach my $link (@links) {
    #print "$$link[0]\t $$link[1]\t $$link[2]\t \r";
    #print substr($$link[2], 0, 50) . " ...\r";
    @urls = (@urls, $$link[2]);
  }
  return @urls;
}


#
# Return 1 if the link has been crawled.
# 
sub linkIsCrawled() {
  my ($new_link) = @_;
  if (exists($links_found{$new_link}) # file found, may or may not crawled.
      && $links_found{$new_link} > 0  # text/html file, found but not crawled.
      ) { 
    #print "link has been crawled: $new_link\n";
    return 1; 
  }
  #print "link has NOT been crawled: $new_link\n";
  return 0;
}


#
# Returns 1 if the link is under url_root.
#
sub isInsideDomain() {
  my ($link) = @_;
  if ($link =~ /^$url_root/i) { return 1; }
  return 0;
}


#
# Get file type and size.
#
# If content_size is not defined, let size be -1.
# If $result->is_error() is true, code may be 404 (not found), 
# 403 (forbidden), 500 (internal server error) etc.
#
# HTTP::Response object: http://lwp.interglacial.com/ch03_05.htm
# 
sub getFileHeader() {
  my ($link, $referer) = @_;

  my $request = new HTTP::Request('HEAD', "$link");
  if ($referer ne "") { $request->referer("$referer"); }
  my $result = $browser->request($request);
  
  # Replaced with the above code using referer.  
  #my $result = $browser->head($link);
  
  if (0) {
    print "status line: " . $result->status_line() . "\n";
    print "status code: " . $result->code() . "\n";
    print "status msg: " . $result->message() . "\n";
    print "status is_error: " . $result->is_error() . "\n";
    print "status is_success: " . $result->is_success() . "\n";
    print "status is_info: " . $result->is_info() . "\n";
    print "status is_redirect: " . $result->is_redirect() . "\n";
    print "header('Location'): " . $result->request->uri . "\n";
    print "status last_modified: " . 
          getLocaltime( $result->last_modified() ) . "\n";
    print "status encoding: " . ($result->content_encoding() // "") . "\n";
    print "status language: " . ($result->content_language() // "") . "\n";
    print "status current_age: " . $result->current_age() . "\n";     # seconds
    print "status lifetime: " . $result->freshness_lifetime() . "\n"; # seconds 
    print "status is_fresh: " . $result->is_fresh() . "\n";
    print "status fresh_until: " . 
          getLocaltime( $result->fresh_until() ) . "\n";
    print "status base: " . $result->base() . "\n";
    print Dumper($result->headers);
    exit(0);
  }
  
  $header_code = $result->code() // ""; # response header code.
  
  if ($result->is_error()) {
    if ($DEBUG) { print "error ($link): code = " . $result->code() . "\n"; }
    return 0;
  }
  # It seems page redirection is handled automatically.
  # E.g., in php, <?php header(Localtion: x.html); ?>, 
  # then content of x.html is actually obtained in getUrl().
  #
  # http://bytes.com/topic/asp-classic/answers/506941-how-handle-
  # webpage-redirection-lwp-perl
  #elsif ($result->is_redirect()) {
  #  print "redirect to: " . $result->headers->location .  "\n";
  #  print $result->as_string . "\n";
  #  exit(0);
  #  return 0; # do not handle 302 redirect yet.
  #}

  my $remote_headers = $result->headers;
  if ($DEBUG) 
  { print "getFileHeader(): " . Dumper($remote_headers); }
  
  # Most servers return content-length, but not always.
  $content_size = $remote_headers->content_length // -1;
  $content_type = $remote_headers->content_type // "";
  
  if ($DEBUG) 
  {
    output ("getFileHeader(): $link type: $content_type, size: $content_size");
  }
  
  return 1;
}


sub getLocaltime() {
  my ($t) = @_;
  if ($t eq "") { return ""; }
  return scalar(localtime($t));
}


#
# Generally there are txt/html files, image files,
# and other multimedia files.
# Here we basically only want txt/html and image files.
#
# The list obiously is incomplete.
#
sub isWantedFile() {
  my ($link, $referer) = @_;

  $content_type = "";
  $content_size = 0;
  $header_code = "";

  if (&linkIsCrawled($link)) { return -1; }
  if ($static_page_only && $link =~ /\?(\S+=\S*)+$/i) { return -2; }

  if (! &getFileHeader($link, $referer)) { return -3; }

  if (! $global_crawl && ! &isInsideDomain($link)) { 
    if ($get_outside_file && ! ($content_type =~ /^text/i)) { return 1; }
    return -4; 
  } 

  # content_size can be null for dynamic pages.
  # content_type may be null, "//" operator is "defined or".
  # both of these 2 may be undefined, but the file still can be downloaded,
  # e.g., for case when ".." is involved, like http://abc.com/../xyz.html
  #if ( ($content_type // "") eq "") { # || $content_size eq "") { 
  #  output("$link: Empty file. Do not download.");
  #  return 0; 
  #}

  return 1;
}


#
# Return the reason rejected by isWantedFile().
#
sub getRejectReason() {
  my ($code) = @_;
  my $msg;
  if ($code == -1) { $msg = "is_crawled"; }    
  elsif ($code == -2) { $msg = "is_dynamic"; }    
  elsif ($code == -3) { $msg = "header_code: $header_code"; }    
  elsif ($code == -4) { $msg = "outside_domain"; }    
  else { $msg = "unknown"; }
  
  return $msg;
}

#
# Get a file's mime sub type.
# 
sub getMimeSubType() {
  my ($type) = @_;
  if (($type // "") ne "") {
    my @tmp = split(';', $type); # for cases like: "text/html; charset=utf-8"
    my @tmp2 = split('/', $tmp[0]);
    #print "mime type: $tmp2[1]\n";
    if (length(@tmp2 >= 2) && $tmp2[1] ne "") {
      return $tmp2[1];      
    }
  }
  return "";
}


#
# Get the hex code of a mime type.
# 
sub getMimeTypeCode() {
  my ($mime) = @_;
  $mime = lc($mime);
  if ($mime =~ /^text/) { return 0x1; }
  elsif ($mime =~ /^image/) { return 0x2; }
  elsif ($mime =~ /^audio/) { return 0x4; }
  elsif ($mime =~ /^video/) { return 0x8; }
  elsif ($mime =~ /^application/) { return 0x10; }
  elsif ($mime =~ /^message/) { return 0x20; }
  elsif ($mime =~ /^model/) { return 0x40; }
  elsif ($mime =~ /^multipart/) { return 0x80; }
  elsif ($mime =~ /^example/) { return 0x100; }
  elsif ($mime =~ /^application\/vnd/) { return 0x200; }
  elsif ($mime =~ /^application\/x/) { return 0x400; }
  else { return 0xFFFFFFFF; } # unknown type, download anyway.
}


#
# Returns 1 if the file's mime type is among the ones wanted.
#
sub mimeTypeMatch() {
  my ($content_type) = @_;
  #print "(&getMimeTypeCode($content_type) & $download_mime_type) != 0 ?\n";
  return (&getMimeTypeCode($content_type) & $download_mime_type) != 0;
}


#
# Returns 1 if file size is between min and max limit, inclusive.
# 
sub fileSizeMatch() {
  my ($content_len) = @_;
  #print "content: $content_len. min=$file_min_size, max=$file_max_size\n";
  if ($content_len == -1) { return 1; } # Header contains no size, download anyway.
  if ($content_len < $file_min_size) { return 0; }
  if (($file_max_size > 0) && ($content_len > $file_max_size)) { return 0; }
  return 1;
}


#
# Save a file to local root.
# 
sub saveContent() {
  my ($url, $content, $content_type, $content_len) = @_;
  my $outfile;
  
  $content_type ||= "";
  if ($verbose & 1) { 
    clearProgressBar();
    output( "   type: $content_type, Size: $content_len" ); 
  }
  if ($content_len <= 0) { return; }
  $download_bytes += $content_len; # public variable for total download size.

  &clearProgressBar();
              
  my $filename = getFilename($url);
  #print "saveContent(). url = $url, filename = $filename\n"  ;
  my $localpath = getLocalPath($url, $filename);
  &createPath($localpath);
  #print "saveContent(). url=$url, localpath = $localpath, filename=$filename\n";
  
  # This happens for default page under a directory.
  if ($filename eq "") { $filename = "index_"; }
    
  if ($filename =~ /\?/) {
    $filename =~ s/\?/-/g; # replace "?" with "-", for dynamic page.
    
    # A dynamic page may be like a.php?x=1&y=2, and has no suffix when save.
    # In this case, get file suffix from content-type. E.g, save as:
    # This will be saved as a.php-x=1&y=2.html
    #print "type: $type\n";
    my $t = &getMimeSubType($content_type);
    if ($t ne "") { $filename .= ".$t"; }
  }
  elsif (! ($filename =~ /\./)) { 
    # this happens when the url ends with "/", 
    # and the file to save is the default under this.
    # for example, index.html or default.html.
    if ($filename eq "") { $filename = "index_"; }
    
    # this happens when the file does not have a suffix, 
    # e.g., when this is the index file under a directory.
    # then the directory name is used as a file name,
    # and no directory is created locally.
    my $t = &getMimeSubType($content_type);
    if ($t ne "") { $filename .= ".$t"; }
    else { $filename .= ".html"; } # default guess
  }
  
  if ($localpath =~ /\/$/) { $outfile = "$localpath$filename"; }
  else { $outfile = "$localpath/$filename"; }  
  
  if ($DEBUG) { output ("save content to: $outfile"); }
  
  if ($flat_localpath && -e $outfile) {
    #print "this file already exists: $outfile, need new name\n";
    $outfile = &resolveConflictName($outfile);
  }
  
  if (open OUTFILE, "> $outfile") {
    binmode(OUTFILE);
    print OUTFILE $content;
    close OUTFILE;
  } else {
    output ("saveContent() error: cannot open file to save to: $outfile");
  }
}


#
# When flat_localpath is used, files from different directory may
# have name conflict, then rename the conflict file. E.g.,
# from file.txt to file_(2).txt, and file_(3).txt etc.
#
# The sequential search below can be made faster by using
# customized binary search.
# 
sub resolveConflictName() {
  my ($outfile) = @_;
  
  my $filename = getFilename($outfile);
  my $outpath = $outfile;
  $outpath =~ s/$filename$//;
  my $suffix = getFileSuffix($filename);
  $filename =~ s/$suffix$//;
  # $outfile is now split to 3 parts: path, name, suffix. 
  #print "outfile: $outfile\n";
  #print "outpath: $outpath, filename: $filename, suffix: $suffix\n";
  
  my $ct = 2;
  while (1) {
    my $outfile = "$outpath$filename\_($ct)$suffix";
    if (! -e $outfile) { return $outfile; }
    ++ $ct;
  }
  
  return ""; # should never happen.
}


#
# Similar to resolveConflictName(), but for directory.
# This is simpler since no need to strip suffix.
#
sub resolveConflictDirName() {
  my ($outfile) = @_;

  my $endChar = "";
  if ($outfile =~ /\/$/) { 
    $endChar = "/";
    $outfile =~ s/\/$//; 
  } # remove trailing "/" if any.

  my $ct = 2;
  while (1) {
    my $outfile = "$outfile\-$ct";
    if (! -e $outfile) { return $outfile . $endChar; }
    ++ $ct;
  }

  return ""; # should never happen.
}


#
# Get suffix path of a filename.
#
sub getFileSuffix() {
  my ($file) = @_;
  my $i = rindex($file, ".");
  my $suffix = substr($file, $i);
  return $suffix;
}


#
# Execute a command and record it in output() function.
#
sub execCmd() {
  my $cmd = shift;
  output($cmd);
  `$cmd`;

  # success/failure of system/`` can be captured by
  # $?. The success return value of system/`` is 0.
  # See: http://www.perlmonks.org/?node_id=486200
  if ($? == -1) {
    output( "execCmd() warning: failed to execute: $!" );
  }
  elsif ($? & 127) {
    output( "execCmd() warning: command died with signal " . ($? & 127) . 
            ", " . (($? & 128) ? 'with' : 'without') . " coredump" );
  }
  elsif ($? != 0) {
    output( "execCmd() warning: command exited with value " . ($? >> 8) );
  }

  return $?;
}


#
# Obtain local path from the remote url path.
# Created needed local directory if needed.
#
sub getLocalPath() {
  my ($path, $filename) = @_;

  # When global_crawl is on, path is outside url_root.
  # Call the extension function.
  if ($global_crawl && ! &isInsideDomain($path)) { 
    return &getLocalPath_outsideDomain($url, $filename);
  } 
  # Otherwise, path is inside url_root. Process below.
  
  if ($flat_localpath) { return $local_root; } # Use flat path.
  
  #my $pattern = "$url_root";
  if ($DEBUG) { 
    print "getLocalPath(): remote path=$path, filename=$filename\n"; 
  }
  if ($path =~ /^$url_root/i) {
    $path =~ s/^$url_root//i;
  } else { # not under the same $url_root. Should not happen here.
    $path = &removeHttpHdr($path);
  }

  # Remove filename from path.
  $path = substr($path, 0, length($path) - length($filename));
  #print "after remove filename: $path\n";
  if ($path =~ /^\//) { $path =~ s/^\///; }
    
  if ($local_root =~ /\/$/) { $path = "$local_root$path"; }
  else {$path = "$local_root/$path"; }
    
  $path = encodePath($path);  
  if($DEBUG) { print "getLocalPath(): local dir=$path\n"; }

  return $path;
}


sub getLocalPath_outsideDomain() {
  my ($path, $filename) = @_;
  
  if ($flat_localpath) {
    $path = encodePath( &getDomain($path) );
    $path = "$local_repos/$path";
    return $path;
  }
  
  $path = &removeHttpHdr($path);
  
  $path = substr($path, 0, length($path) - length($filename));
  $path = "$local_repos" . encodePath($path);
  #print "getLocalPath_outsideDomain: path=$path, file=$filename\n";
  
  return $path;
}


#
# path name (in windows) cannot be any of: \/:*?"<>|
# replace these with "-", e.g., for port number: http://a.com:8080.
# \ and / don't have to be included, since they are url delimiter too.
#
sub encodePath() {
  my ($path) = @_;
  if ($path =~ m/[\:\*\?\"\<\>\|]/) {
    $path =~ s/[\:\*\?\"\<\>\|]/-/g; 
  }  
  return $path;
}


sub createPath() {
  my ($path) = @_;
  if (-d $path) { return 1; }

  #mkdir ($path, 0700);
  &execCmd("mkdir -p \"$path\"");
  if (! -d $path) { return 0; }
  return 1;
}

#
# Extract filename from the url.
# Need to remove suffix including "?.." and "#..".
#
sub getFilename() {
  my ($path) = @_;
  my $filename = "";
  
  $path = &removeHttpHdr($path);
  
  my $i = rindex($path, "/");
  if ($i > 0) { $filename = substr($path, $i + 1); }
  #if ($DEBUG) { print "getFilename(): i=$i, url=$path, filename=$filename\n"; #}
  return $filename;
}


#
# Given a url, return the path without filename.
#
sub getUrlPath() {
  my ($path) = @_;

  # if $path ends with "/", just return it.
  if ($path =~ m/\/$/) { return $path; }

  # else, remove the filename path and return the rest.
  my $file = &getFilename($path);
  $path =~ s/$file$//;

  return $path;
}


#
# Print to both STDOUT and log file.
#
sub output {
  my ($msg) = @_;

  print "$msg\n";
  
  # Log for every change by flush log file handle.
  # If log in batch mode, may lose intermediate 
  # information when the program process is killed.
  print LOGFILE (localtime(time) . " $msg\n");
  LOGFILE->autoflush;
}


sub logLnkFound() {
  my ($msg) = @_;
  print LOG_Lnk_Found ("$msg\n");
  LOG_Lnk_Found->autoflush;
}

sub logLnkQueue() {
  my ($msg) = @_;
  print LOG_Lnk_Queue ("$msg\n");
  LOG_Lnk_Queue->autoflush;
}

sub logLnkQueueIndex() {
  my ($msg) = @_;
  open LOG_Lnk_Queue_Index, "> " . &getLnkQueueIndexLog();
  print LOG_Lnk_Queue_Index ("$msg\n");
  close LOG_Lnk_Queue_Index;
}

sub logLastUrlStart() {
   my $file = &getLastUrlStartLog();
   open FILE, "> $file" or die "Cannot open file to save: $file";
   print FILE ($url_start);
   close FILE;
}


#
# This function is used by parseLinks().
# Add any customized links here. 
#
sub getCustomLinks() {
  my ($s) = @_;
  #return $s;
  
  # In some pages, <img data-original="..."> should be <img src="...">
  if ($s =~ m/data\-original/i) {
    #print "replace data-original: $url\n";
    $s =~ s/data\-original/src/gi; # for <img />
  }
  
  return $s;
}




######################################################
# Change log
######################################################
# 7/25/2014
# - Simplified function resolveConflictName().
#   Previously loop through entire DIR to find files with name
#   file_(k), now just test for the existence of files file_(k)
#   for k = 2, ..., n. Could be faster using binary search.
# - Added left time display to progressBar().
# - change -V from on/off to value based, to allow msg at
#   different levels. At level 1 the msg is the same as before,
#   at level 2 message is about new_link reject/ignore reason.
# - Change default of url_root when it's not given: previously
#   use domain name of url_start, now use the longest path of url_start.
# - for -i, now default is 1.
# - For overwrite -o, now move the previous folder to folder-2,
#   instead of delete.
# - Added -p option to mkdir, so intermediate path can be generated.
# - Fixed small bug with log_.._lnk_Q_ID.log, so only one value
#   is logged, instead of all.
#
# 7/24/2014
# - Now in getFileHeader(), can get all response fields.
#   Use is_error(), in that case return 0, so isWantedFile()
#   returns false.
# - Added function getCustomLinks(), to handle non-standard links,
#   such as jquery lazy loading contents. For example, <img src="a.jpg"> 
#   would become <img class="lazy" data-original="a.jpg">,
#   then it needs to do the replacement in getCustomLinks() to
#   be able to get the image.
# - Remove $plain_txt_only and corresponding command line option,
#   because now this can be specified by mime-type option -m/--mime-type.
# - Added function parseHtml(), and added html parser in another module 
#   pparse.pm. This can be saved to database etc. This deserves a 
#   separate module. It extracts text into an array @lines so far.
#   But I don't want to implement it now, since there is no need 
#   at this time. 
#
# 7/23/2014
# - Now in getUrl() no longer calls head() to get content type/size.
#   Such information are obtained from getFileHeader() which is 
#   called in isWantedFile(). For text/html files, they are always
#   downloaded no matter what size is, and type is always "text/html".
#   This change saves 1 request per file, previously 3 request per file
#   (2 head, 1 get), now 2 (1 head, 1 get). Also removed LWP:Simple
#   module, so browser agent is now unified into one.
# - Now added referer to head and get requests.
# - Now wait for 5 seconds before requesting another html file,
#   and wait for 1 second before requesting another link on the file.
#   This way it's nice and won't get remote server reject request.
#
# 7/22/2014
# - added support such that a session starting from different url_start 
#   can avoid crawling processed pages of previous sessions.
#   It does this by checking .pcraw_lnk_found.log, if a text/html file's
#   hash value is positive, then it's already processed.
#   Note: if the needed file mime type is different, then this won't work.
#   Say a first session downloaded text files only, the second session
#   want images, then it does not know this difference, and will not
#   processed crawled page. The possible fix is to add mime type to
#   the log, but that's unnecessarily complex at this time.
#
# - added log .pcraw_last_url_start.log, about the previous url_start
#   used. But this is not used in any places yet, so just for information.
#
# - added support for global crawl - not limited to under url_root.
#   this is specified using -g or --gobal-crawl.
#
# = So, the current log structure is:
#   - shared logs: 
#     - .pcraw_lnk_found.log : only all links found, and whether crawled
#       (hash absolute value is crawl depth, + means crawled/processed,
#        - means not crawled yet)
#     - .pcraw_last_url_start.log : previous url_start value. No use otherwise.
#   - logs for each download session:
#     - .pcraw_[filename]_lnk_Q.log : html links in the queue, to be crawled.
#     - .pcraw_[filename]_lnk_Q_ID.log: pointer/index in current lnk_Q.
# = Current behavior:
#   - The user can stop a download session by Ctrl-C.
#   - The user can resume a download session from the broken point.
#   - The user can start from a different url_start under the same url_root,
#     the download will avoid processing crawled html files.
#   - For each download session, at least one of url_root and url_start 
#     must be provided. url_root should be a prefix of url_start.
#     If url_start is missing, it is assigned the value of url_root;
#     If url_root is missing, it is assigned the domain name part of url_start.
#     But a url_root can contain sub path, as long as it is a prefix of url_start.
#
# 7/21/2014
# - added cookie support
# - added browser agent simulation (firefox)
# - added hash %links_found.
# - add history record: .pcraw_lnk_found/Q/Q_ID config files under
#   local_root. Added option switch -o and --overwrite for this.
#   - Now each url_start has 2 related log files: _Q.log and _Q_ID.log
#     Another global log _found.log logs all files completed crawl and download.
#     Under the same url_root, starting from different url_start is possible,
#     completed files will not crawl and download again.
#
# 7/18/2014 
# - Changed doCrawl(). 
#   Now put non-text files to @non_link_queue, and won't be crawled.
#   Text files are stored in @link_queue.
# - Added mime type constraint.
# - Added file min/max size constraint.
# - Added wait interval before crawl next page.
# - Change $test_crawl to $crawl_number, and change switch from -t to -n.
# - Change $crawl_number from on/off to number of links to crawl.
# - Added support for flat local path: -f.
# - For flat local path, allow resolve filename conflict:
#   rename from file.txt to file_(2).txt, file_(3) etc.
#
# 7/17/2014
# - Added perldoc message.
# - Added download total bytes count.
# - Added command line option switches.
# - Added download progress bar.
# - Added package name.
# - Changed file name from craw.pl to pcraw.pl.
#
######################################################

