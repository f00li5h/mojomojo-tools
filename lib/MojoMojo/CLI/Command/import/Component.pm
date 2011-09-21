package MojoMojo::CLI::Command::import::Component;

use warnings; use strict;

use base qw[ Exporter ];
our @EXPORT = qw[ SELF CONTEXT OPT ARG ];


sub SELF { 0}
sub CONTEXT {1}
sub OPT { 2}
sub ARG     {3}

sub skip_me {
	my ($self,$c, $opt, $args) = @_;

	1 # can't just have things existing be loaded and run by default
	  # the dispatchinator will not call ->your_role if you return 1

	  # use this if your arguments don't validate ... 
}

sub opt_spec {
	# these things appear in help ... 
	my ($self,$c, $opt, $args) = @_;
	
	()
}

sub new { return bless {}, shift }

1


