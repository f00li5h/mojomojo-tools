
package MojoMojo::CLI::Command::import::Finalise::LoadIntoMojoMojo;
use base qw[ MojoMojo::CLI::Command::import::Component ];

use warnings;
use strict;

use constant abstract => 'Stuff things into the mojomojo schema, the hard way';

sub opt_spec { 
return (
    ['mojo-namespace=s', 'the base for the import' ],
    ['mojo-index=s',     'the index name, /mojo-index -> /'],
)
}

sub skip_me {
	my  ($self,$c, $opt, $args) = @_;
	return 0 if  
		$opt->{'mojo_index'}  or 
		$opt->{'mojo_namespace'};
	return 1;
}

sub finalise {
	my  ($self,$c, $opt, $args) = @_;

	my $schema      = $c->app->schema;
	my $index_name  = $opt->{'mojo_index'}     || '';
    	my $page_prefix = $opt->{'mojo_namespace'} || '';
	   $page_prefix.= '/' unless $page_prefix =~ m{/$};

	my $file_prefix = '';
	
	for my $path ( keys %{ $c->stash->{pages} } ) {
		my $record = $c->stash->{pages}{ $path };
	        print "$path ";
		
		my $page_name = $path;
		$page_name =~ s/^$file_prefix//;

		use File::Basename;
		# /path/index -> /path/
		$page_name =~ s/$index_name$// if basename($page_name) eq $index_name;
		my $page_path  = $page_prefix . $page_name;
		$page_path =~ s{/+}{/}g;

		my $revs = scalar @{ $record->{revision}};
		print "-> $page_path :", 
			$revs, 
			$revs == 1 ? ' revision' : ' revisions'
		;
	

		my $date = DateTime->now;

		my ( $path_pages, $proto_pages ) = $schema->resultset('Page')->path_pages( $page_path );
		
		my $page = 	@$proto_pages > 0
				? $proto_pages->[-1]
				: $path_pages->[-1]
				;
		if ( @$path_pages){
		    $path_pages = $schema->resultset('Page')->create_path_pages(
			path_pages  => $path_pages,
			proto_pages => $proto_pages,
			creator     => 'c/,,\\',

			release_date    => $date,
			created         => $date,
			status 		=> 'released'
		    );
		    $page = $path_pages->[-1];
		}
		use Date::Manip;
		for my $rev (@{  $record->{revision} }) {
			my $date;
			if ( (ref $rev->{timestamp}) =~ /DateTime.*/ ) { # handy, it's already a DateTime
				$date = $rev->{timestamp};
			}
			else {
				my $date_unix;
				if ($rev->{timestamp} =~ /^\d+$/) { # looks like a unix date
					$date_unix = $rev->{timestamp};
				}
				else { 					# get some parsing on...
					$date_unix = UnixDate(
						ParseDate( $rev->{timestamp} ),
						'%s'
					);
				}
				#print $rev->{timestamp}, " -> ",$date_unix, "\n";
				$date = DateTime->from_epoch(
					epoch => $date_unix || 0
				);
			}
			my $user = $rev->{contributor}{username}
					|| 'c/,,\\';
				# id username ip
				
			my $content = $rev->{text};
			my $comment = $rev->{comment} ||'';
			print "\n",
				$date->ymd . ' ' . $date->hms . ' ' ,
				$c->app->preview( do {(my $copy=$content) =~ s/(\s+)/ /g; $copy} , 80),
				$user;

			if ($rev->{tags}) { 
				warn "Tagging '$page_path' with ".join ', ', @{ $rev->{tags} };
				$page->create_related('tags', { tag => $_, person => $user } )
					for @{ $rev->{tags} } ;
			}
			$page->update_content(
				creator 	=> $user,
				body 		=> $content,
				precompiled 	=> '',  # MojoMojo will re-compile it
				release_date    => $date,
				created         => $date,
				status 		=> 'released',
				abstract	=> $comment,
			);

		}
			
			
		print "(" . $date->ymd , " at " ,$date->hms,  " Done.\n";
	}

}
1
