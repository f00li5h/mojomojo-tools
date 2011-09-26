package MojoMojo::CLI::Command::import::Load::DirectoryOfText;
use base qw[ MojoMojo::CLI::Command::import::Component ];

use warnings; use strict;

sub opt_spec { 
return (
	['from-directory=s@', 'a stack of plain text' ],
	['trim-names=s',      'remove this from the start of the name [default is --from-directory+/]' ],
	['index-name=s',      'the file name to use as the contents' ],
)
}
use constant abstract => "import a directory of text files... no magic except #ABSTRACT:...\\n";
use Data::Dumper;

sub skip_me {
	my ($self,$c, $opt, $args) = @_;
	return "no directoryto load from"
		if not exists $opt->{'from_directory'};

	()
		
}

sub handle { 
	my ($self, $extension, $content) = @_;

	my %handler_for = (
		pod 	=> sub { join "\n\n","{{pod}}", @_ , "{{end}}" },
		html 	=> sub { },
		pm 	=> sub { warn "skipping it", next },
	);

	exists $handler_for{ $extension }
		? $handler_for{ $extension } -> ($content)
		: $content

}

sub load { 
	my ($self,$c, $opt, $args) = @_;

	my $from_directory = $opt->{'from_directory'};
	my $trim_name   = $opt->{'trim_names'} ||  ('(' . (join '|', sort @{ $from_directory }) . ')' );
	my $index_name  = $opt->{'index_name'} || 'index';

	my @paths = @{ $from_directory };

	my $started = time;
	print "starting on @paths";

	while (defined(my $path = shift @paths) ) {
	        print "$path ";

		if (-d $path) { 
			opendir my($dh), $path;
			unshift @paths, map "$path/$_", grep { $_ ne '..' and $_ ne '.' } readdir$dh;
			print ": (recursing)\n" and next
		}
		
		# find extension, strip prefix...
		my $extension = '';
	 	   $extension  = $1 if (my $page_name = $path) =~  s/[.]([^.]+)$//;
					   $page_name =~ s{^$trim_name[/]?}{};
		use File::Basename;
		# /path/index -> /path/
		$page_name =~ s/$index_name$// if basename($page_name) eq $index_name;
		my $page_path  = $page_name;

		$page_path =~ s{/+}{/}g;

		print "-> $page_path :";


		# my $date = DateTime->from_epoch( epoch  =>  10 * 60 * 60 + $started + -M $path );

		my $content = do { local (@ARGV, $/) = $path; <> } || ''; 

		my $abstract; $abstract = $1 if $content =~ s/#ABSTRACT:\s*(.*)//;
		my $filtered_content = $self->handle( $extension =>  $content );

		print "#ABSTRACT: $abstract" if $abstract;
		
		use DateTime;
		# print preview( do {(my $copy=$content) =~ s/(\s+)/ /g; $copy} , 80) ;
		$c->stash->{pages}->{ $page_path } = {
			title => $page_path,
			id =>    $page_path,
			revision => [ {
					comment => $abstract,
					contributor => {
						ip  		=> 'o_O', 
						username 	=> 'o_O', 
						id  		=> 'o_O', 
					},
					timestamp => DateTime->from_epoch( epoch  =>  10 * 60 * 60 + $started + -M $path ),
					text => $filtered_content
				} ],
		};
		#print "(" . $date->ymd , " at " ,$date->hms,  " Done.\n";
		print "\n";
	}
}
1
__END__
	
		# keys of page is an id
		%{ $c->stash->{pages} } = 
		map {
			$struct->{'page'}->{$_}->{title}
			=> {
			'id' => $_,
			%{ $struct->{'page'}->{$_} }
			}
		}
		keys %{
			$struct->{'page'}
		}
