package MojoMojo::CLI::Command::rm;
use MojoMojo::CLI -command;
use strict; use warnings;

use Term::Prompt;

use constant {
	abstract	=> "remove page",
	description 	=> "remove a page, by name or id ",
};
sub opt_spec {
return (
       );
}

sub validate_args {
	my ($self, $opt, $args) = @_;

# no args allowed but options!
#$self->usage_error("No args allowed") if @$args;
}


sub delete_page {
	my $self = shift;
	my $schema = $self->app->schema;
	my $id = shift;

	print "Erasing page: ";
	my $page ;
	if ($id =~ m{/}) { 
		my ( $path_pages, $proto_pages ) = $schema->resultset('Page')->path_pages( $id );
		$page = 	@$proto_pages > 0 ? $proto_pages->[-1] : $path_pages->[-1] ;	
		$id=$page->id;

	}
	else{
		$page = $schema->resultset('Page')->find( { id => $id } );
	}
	print $page->name_orig, "\n";
		my $page_version_rs =
			$schema->resultset('PageVersion')->search( { page => $id } )->delete_all;
		my $content_rs =
			$schema->resultset('Content')->search( { page => $id } )->delete_all;
		my $attachment_rs =
			$schema->resultset('Attachment')->search( { page => $id } )->delete_all;
		my $comment_rs =
			$schema->resultset('Comment')->search( { page => $id } )->delete_all;
		my $link_rs =
			$schema->resultset('Link')
			->search( [ { from_page => $id }, { to_page => $id } ] )->delete_all;
		my $role_privilege_rs =
			$schema->resultset('RolePrivilege')->search( { page => $id } )->delete_all;
		my $tag_rs = $schema->resultset('Tag')->search( { page => $id } )->delete_all;
		my $wanted_page =
			$schema->resultset('WantedPage')->search( { from_page => $id } )->delete_all;
		my $journal_rs =
			$schema->resultset('Journal')->search( { pageid => $id } )->delete_all;
		my $entry_rs =
			$schema->resultset('Entry')->search( { journal => $id } )->delete_all;
		my $page_rs = $schema->resultset('Page')->search( { id => $id } );
	$page_rs->delete_all;
}



sub execute {
	my ($self, $opt, $args) = @_;
	#$ my $page_id = prompt('n', 'Input ID of Page to Delete:', '', '' );
	# if ( $page_id == 0 ) { die "You must select a positive integer.\n"; } die "it's busted";

	$self->delete_page( $args->[0]);


}

1
