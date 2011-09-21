
package MojoMojo::CLI::Command::dump;
use MojoMojo::CLI -command;
use strict; use warnings;

use constant {
	abstract	=> "debug things",
	description 	=> "generally ruin things by running assorted cruft",
};

sub opt_spec {
return (
	[ "blortex|X",  "use the blortex algorithm" ],
	[ "recheck|r",  "recheck all results"       ],
       );
}

sub validate_args {
	my ($self, $opt, $args) = @_;

# no args allowed but options!
	$self->usage_error("No args allowed") if @$args;
}

sub execute {
	my ($self, $opt, $args) = @_;

	use Data::Dumper;
	print Dumper $self;
	#print Dumper +($self->app->page('/'))[1]->body;
	print Dumper $self->app->author;
	
}

1
