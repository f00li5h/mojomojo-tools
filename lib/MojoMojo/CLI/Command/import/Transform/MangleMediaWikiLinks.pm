package MojoMojo::CLI::Command::import::Transform::ManglePages;

use base qw[ MojoMojo::CLI::Command::import::Component ];

use warnings; use strict;

use constant ( abstract => 'Mangle mediawiki categories->tags and links');

sub opt_spec {
	return (
	['links','correct mediawiki link sillyness (in all revs)'],
	['tags:s',q{mediawiki uses [[Category:Foo]] links to categorise pages. mojomojo has tags instead
				=no:     leave links.  no tagging.
				=remove: strip links.  no tagging.
				=leave:  leave links.  tagging.
				defualt: strip links.  tagging. }],
        ['mojo-namespace=s', 'the base for the import (shared)' ],
	

	)
}

sub skip_me {
	my ($self,$c, $opt, $args) = @_;
	not (
		exists $opt->{'links'} 
	);
}

sub link_callback {
	my ($self, $link, $rev, $options) = @_ ;

	my ($link_to, $link_text, $page_name, $page_prefix, $category_callback) = (
		$link->{link}, $link->{title}, $link->{in_page},
		$options->{page_prefix},
		sub { push @{ $rev->{tags} }, @_ if $options->{tags_from_category_links}; }
	);

	return '' if $link_to eq $page_name;       # don't link to yourself
	return '' if $link_to =~ /^:Category:/;    # don't link to categories 

	warn "$link_to looks like it should be an attachment ... but i have no idea what to do with those"
		if $link_to =~ /^File:/ and 0;

	if ($link_to =~ /^Category:([^|]*)/ ){# pipe is for labels...
		$category_callback->($1) if  $options->{tags_from_category_links};
		return '' 		 if $options->{remove_category_links};
		
	}


	'[['			# these aren't uri's since [[ ]] is just a page name in mediawiki
		. ($page_prefix || '')
		.  mojo_name_for($link_to)
		.  (defined($link_text) ? "|$link_text" :"" )
	. ']]'
}
sub mojo_name_for { 
	my $name = shift;
	return $name if $name =~ qr{^https?://};
	# FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
	(my $new_name =  lc($name) ) =~ s/[.]/_/g;

	$new_name
}

sub transform {
	my ($self,$c, $opt, $args) = @_;

       my $page_prefix = $opt->{'mojo_namespace'} || '';
           $page_prefix.= '/' unless $page_prefix =~ m{/$};
	my $options = {
		page_prefix 		 => $page_prefix,
		remove_category_links 	 => 1,
		tags_from_category_links => 1,
	};

	$options->{remove_category_links}    = 0
			if exists  $opt->{tags}
			    and grep $opt->{tags} =~ $_, qw[ leave  no ];

	$options->{tags_from_category_links} = 0
			if exists  $opt->{tags}
			    and grep $opt->{tags} =~ $_, qw[ remove no ];
	

	
	for ( keys %{ $c->stash->{pages} } ) {
		my $new_name = mojo_name_for( $_ );

		# move it, rewrite the links later...
		$c->stash->{pages}->{$new_name} = delete $c->stash->{pages}->{$_}
			if $new_name ne $_;

		# gee, this will break all the links 
	}

	# do the replacing 
	$c->apply_to_page( sub {
		my $page_name = $_;
		for my $rev( @{ $_[0]->{revision} } ) {
			
			 $rev->{text} =~ s/__(NOEDITSECTION|NOTOC)__//g;


			# my wiki is full of [[Main Page]] > [ some shit ] > [This Page] type nagivation
			# mojo mojo has this ... and it's not really content ... 
			(my $title_pattern = $_[0]->{title}) =~ s/[ _]/[ _-]/g;
			 my $banner = qr/\[\[Main[ _-]Page(?:\|[^\]]*)?\]\].+\[\[$title_pattern(?:\|[^\]]*)?\]\].*/;

# warn $banner;
			$rev->{text} =~ s/$banner//i;

			# mojomojo wants lowercase page names ....
			# [[SomeCats]] -> [[somecats]
			$rev->{text} =~ s{
			\[\[
			([^\]|]+)
			(?:
				[|]
				([^\]]+)
			)?
			\]\]
			}
			{
			$self->link_callback( { 
					link => $1,
					title => $2,
					in_page => $page_name,
				},
				$rev,
				$options
			);
			}gex;
		}
	});
	
} 1
