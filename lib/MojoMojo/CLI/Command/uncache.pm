
package MojoMojo::CLI::Command::uncache;
use MojoMojo::CLI -command;
use strict; use warnings;
# ABSTRACT: nipples.


use constant {
	abstract	=> "clear rederer cache for listed pages",
	description 	=> "remove the cached version of pages, causing MojoMojo to recompile them",
};

sub validate_args {
	my ($self, $opt, $args) = @_;
	$self->usage_error("No options allowed") if %$opt;
}

sub execute {
	my ($self, $opt, $args) = @_;
	for my $page_path ( @{ $args } ) { 
		my ($page, $page_content, undef, undef) = $self->app->page(
			$page_path 
		);
		if (defined $page_content) { 
			print $page_content->precompiled;
			$page_content->update({
			    precompiled => ''
			});
			print "cleared cache for $page_path";
		}
		else { 
			print "skipped $page_path";
		}
		print "  (id:", $page->id, ")\n";
	}

#my $result = $opt->{blortex} ? blortex() : blort();
#recheck($result) if $opt->{recheck};
#print $result;
}

1
