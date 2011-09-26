package MojoMojo::CLI::Command::import::Load::Feed;
use base qw[ MojoMojo::CLI::Command::import::Component ];

use warnings; use strict;

use constant abstract => 'Fill your wiki with things from a feed';

sub opt_spec { 
return (
	['feed-from=s@',    'which mediawiki feed file to load from' ],
)
}
use Data::Dumper;

sub skip_me {
	my ($self,$c, $opt, $args) = @_;
	return "no file to load from"
		if not exists $opt->{'feed_from'};

	()
}

sub load { 

	my ($self,$c, $opt, $args) = @_;

	my @feeds = 'ARRAY' eq ref    $opt->{'feed_from'}
				?  @{ $opt->{'feed_from'} }
				:     $opt->{'feed_from'} 
				;

	while (defined(my $path = shift @feeds) ) {
		use XML::Feed;
		my $r = XML::Feed->parse(URI->new($path));
		if ($r) {
		    for my $e ( $r->entries ){

			my %seen_tag;
			my @tags =  grep {!$seen_tag{$_}++ } $e->tags;
			
			my $page = {
				title => $e->title,
				revisions => [ {
					tags => \@tags,
					contributor =>{ username => $e->author || 'c/,,\\' },
					text =>  eval{ $e->content->body } || '',
					comment =>  eval{ $e->summary->body } || '',
					source => $path,
					timestamp =>  sub {
					eval { $e->issued->epoch   }
				     || eval { $e->modified->epoch }
				     || eval { eval"use DateTime"; DateTime->now->epoch; }
				     || time
				   }
				}]
			};

			#TODO: feedburner mangles your uris, HEAD it to get the url ...

			use URI;
			my $org_url = URI->new(  $e->link );
			my $path = $org_url->path;

			warn $org_url;
			use File::Basename qw[ basename ];
			$path=basename($path)
				if $org_url->host eq 'feedproxy.google.com';


			$c->stash->{pages}{$path} = $page;
		    }
		}
		else {
			warn "skipped $path: $r";

		}


		print "\n";
	}

	print 'feed-debug: ' . Dumper ($c->stash->{pages}) if $opt->{feed_debug};
}

1
