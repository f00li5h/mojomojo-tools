package MojoMojo::CLI::Command::edit;
use MojoMojo::CLI -command;
use strict; use warnings;

use Term::Prompt;

use constant {
	abstract	=> "edit a wiki page/revision",
	description 	=> "spawn your favoured editor and edit the content of a page. can edit the revision in place, or save to a new revision (which is like reverting)",
};
sub opt_spec {
return (
	[ "inplace|i",     "edit revision in place (update the revision directly - timetravel)" ],
	[ "revision|r:i",  "start editing at revision <number>"       				],
       );
}

sub validate_args {
	my ($self, $opt, $args) = @_;

# no args allowed but options!
#$self->usage_error("No args allowed") if @$args;
}




sub execute {
	my ($self, $opt, $args) = @_;


	my ($starting_revision) = map {/\@(\d+)/ ? $1  : undef } @$args;
	my ($page_path) = shift @$args;

	my ($inplace) = $opt->{i} || 0;

        my $schema      = $self->app->schema;


	my ( $path_pages, $proto_pages ) = $schema->resultset('Page')->path_pages( $page_path );

	
    	my $page = @$proto_pages > 0
		? $proto_pages->[-1]
		: $path_pages->[-1]
		;
	if ( @$path_pages){
            $path_pages = $schema->resultset('Page')->create_path_pages(
                path_pages  => $path_pages,
                proto_pages => $proto_pages,
                creator     => 'c/,,\\',
            );
            $page = $path_pages->[-1];
	}

	# Get the lastest/requested content version of the page
	my $page_content= $schema->resultset('Content')->find(
	    {
		page    => $page->id,
		version => $starting_revision // $page->content_version,
	    }
	);
	if (not defined $page_content) {
		warn "You can't inplace edit a revision that doesn't exist,
so i'll be creating a new one for you." if $inplace;
		$inplace = 0; 
		sleep 1; 
	}

	my $previous_content = eval { $page_content->body } || '';


	# ask the user what they want to put in place instead
	use Term::CallEditor; 
	my $file_content = solicit($previous_content);
	die "$Term::CallEditor::errstr\n" unless $file_content;
	my $content =  do{local $/;  <$file_content>};
 
	return "$page_path: Unchanged." if $previous_content eq $content;

	if ( $inplace ) { 
		print "Are you sure you want to replace this revision?\n",
		    preview($previous_content, 300),
                    "\nwith\n",
		    preview($content, 300),
		    "\n? ('yes'/'new' revision/anything else to abort): ";

		chomp ( my $answer = <STDIN> );
	
		if ($answer eq 'yes') {
		    $page_content->update( {
			    body => $content,
			    precompiled => '',  # MojoMojo will re-compile it
			});
		}
		elsif ($answer eq 'new') { 
		    print "creating a new revision with your stuff... ";
		    # just fall through
		} else {
		    eval q/END{$?=1}/;
		    return "Aborted.";
		}
	}

	$page->update_content(
		creator 	=> 'c/,,\\',
		body 		=> $content,
	    	precompiled 	=> '',  # MojoMojo will re-compile it
	);
		
		
	"$page_path: Done.";
}
1
