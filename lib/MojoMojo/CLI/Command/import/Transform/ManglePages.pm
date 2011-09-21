package MojoMojo::CLI::Command::import::Transform::ManglePages;

use base qw[ MojoMojo::CLI::Command::import::Component ];

use warnings; use strict;

sub opt_spec {
	return (
	['replace:s@','do some replaces on stuff, needs --s'],
	['replace-debug','belch out debug stuff'],
	['replace-all','do replaces on all versions of every page (rather than on a copy of the latest)'],
	#['s:s@',  'replaces to do on pages --s{}{} or --s///'],
	)
}


sub skip_me {
	my ($self,$c, $opt, $args) = @_;
	not (
		exists $opt->{'replace'} or exists $opt->{'replace_debug'} 
	);
}

sub transform {
	my ($self,$c, $opt, $args) = @_;

	$opt->{'replace'} and $opt->{'replace_debug'} and warn "replacing " . $opt->{'replace'};

	# parse out the expressions 
	
	# do the replacing 
	$c->apply_to_page( sub { 
		warn "replace-debug: manging $_" if $opt->{'replace_debug'};
		my $rev = { %{  $_[0]->{revision}[-1] }};
		for  (@{ $opt->{'replace'} }) {
			my $old_version = $rev->{text};
				
			my ($pattern,$replace,$mod);
			   ($pattern,$replace,$mod) = ($1,$2,$3) if m{/([^/]+)/([^/]+)/(.*)} ;
			   ($pattern,$replace,$mod) = ($1,$2,$3) if m|{([^}]+)}{([^}]+)}(.*)|;

			die "I can't find a regex+replace in:'$_' - I can only parse s{}{} and s/// with an optional g. (Also, s{ {}}{} is NOT cool.)" if not $pattern or not $replace;


			$rev->{text} =~ s/$pattern/$replace/e  if $mod ne 'g' ; 
			$rev->{text} =~ s/$pattern/$replace/eg if $mod eq 'g' ; 
		warn "replace-debug:\npattern: $pattern\nreplace: $replace on\n$old_version \n\ngave me:\n $rev->{text}" if $opt->{'replace_debug'};
		}
		push @{ $_[0]->{revision} }, $rev
	});

} 1
