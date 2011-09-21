package MojoMojo::CLI::Command::import::Transform::DropPages;

use base qw[ MojoMojo::CLI::Command::import::Component ];

use warnings; use strict;
my @default_drop = (
    'password',
    'clear text' ,
    '^User:',
    '^File:',
    '^MediaWiki:',
    '^Category:', 
);

sub opt_spec {
	return (
	['drop-named:s@', 'remove pages whos names match this'],
	['drop-nothing',  'do not remove anything (Default drops mediawiki-ish things)'],
	['drop-debug',    'list the things that match (and are dropped)'],
	)
}


sub skip_me {
	my ($self,$c, $opt, $args) = @_;
	return 1 if exists $opt->{'drop_nothing'};
	return 0 if not exists  $opt->{'drop_named'}; 
	return 1 if ''  eq $opt->{'drop_named'};
}

sub transform {
	my ($self,$c, $opt, $args) = @_;
	return if  $opt->{'drop_nothing'};
	local $" = ', ';

	my @drop = @default_drop;
	@drop = @{'ARRAY' eq ref $opt->{drop_named} ?  $opt->{drop_named} : [ $opt->{drop_named} ] }
		if exists $opt->{'drop_named'};


	warn "going to drop pages matching any of: @drop" if $opt->{'drop_debug'};

	my @unwanted_pages = grep {
			my $skip = 0;
			my $page_name = $_;
			   $page_name =~ $_ and $skip =1, last for @drop;
			$skip;
			
		} keys %{ $c->stash->{pages} };

	warn "dropping @unwanted_pages"
		if $opt->{'drop_debug'};

	delete @{ $c->stash->{ pages} }{ @unwanted_pages } 
}
1
