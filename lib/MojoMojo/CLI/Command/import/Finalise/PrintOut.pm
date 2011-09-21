
package MojoMojo::CLI::Command::import::Finalise::PrintOut;
use MojoMojo::CLI::Command::import::Component;
use base qw[ MojoMojo::CLI::Command::import::Component ];

use strict;
use warnings;

sub opt_spec {
return (
	['print:s',"show what's loaded, titles (=long for titles,revs and comments"],
	['dump:s','=s dump the contents of a title'],
)
}

sub skip_me {
	# warn       $_[OPT]->{print};
	not exists $_[OPT]->{print}
}

sub finalise {
	my ($self,$c, $opt, $args) = @_;
	print "We have pages called: \n";


	print join "\n",
		keys %{ $c->stash->{pages} } 
	if exists $opt->{print} 
	   and 'long' ne $opt->{print} ;

	print 'Long' . join "\n",
		map {
			($_->{title} || 'o_O')
			. "\n - "
			. join "\n - ",
			   map {
				'@'.($_->{timestamp} || '')
				. " " . ($_->{comment} ||  '-> '. $c->app->preview( $_->{text}, 40 ))
			
			}@{  
				$_->{revision}
			}
		} values %{ $c->stash->{pages} } 
	if exists $opt->{print} 
	   and 'long' eq $opt->{print} ;


	use Data::Dumper;
	print Dumper $c->stash->{pages}->{ $opt->{dump} }
		if $opt->{dump};
}
1
