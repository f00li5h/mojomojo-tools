#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use MojoMojo::Schema;

use App::Rad;
App::Rad->run();


sub preview { # {{{
	my $self = shift; # lol, oo
    my ($string, $limit) = @_;
    my $length = length $string;
    return $string if $length <= $limit;
    my $middle = ' [...] ';
    return 
        substr( $string, 0, ($limit+1 - length $middle)/2 )
      . $middle
      . substr( $string, $length - ($limit-1 - length $middle)/2 )
    ;   
} # }}}

sub setup {
	my ($c) = shift;
	$c->register_commands( qw[ edit replace touch import_path rm ]);
	$c->register ( vi => \&edit,	'(alias of edit)' );

	use Config::JFDI; use Cwd;
	my ($config, $jfdi, $faked_it); 
	{
	    $config = ($jfdi = Config::JFDI->new(
		name => "MojoMojo",
		path => getcwd(),
		))->get;

	($faked_it,$ENV{MOJOMOJO_CONFIG})=(1,'./MojoMojo.conf'), warn "trying ./MojoMojo.conf",redo
		if not keys %{$config} and not $faked_it;


	die "Couldn't read config file, tried "
		. getcwd()
		. ' and found: '
		. join ", ", $jfdi->found
			if not keys %{$config} and $faked_it;


	}

    my ($dsn, $user, $pass) = eval {
        if (ref $config->{'Model::DBIC'}->{'connect_info'} eq 'HASH') {
            ( $config->{'Model::DBIC'}->{'connect_info'}->{dsn},
            $config->{'Model::DBIC'}->{'connect_info'}->{user},
             $config->{'Model::DBIC'}->{'connect_info'}->{password})
        } else {
            @{$config->{'Model::DBIC'}->{connect_info}};
        }
    };
    die "Your DSN settings in mojomojo.conf seem invalid: $@\n" if $@;
	die "Couldn't find a valid Data Source Name (DSN).\n" if !$dsn;

	$dsn =~ s/__HOME__/$FindBin::Bin\/\.\./g;

	$c->stash->{schema} = 
		MojoMojo::Schema->connect($dsn, $user, $pass) or
			die "Failed to connect to database";
}

sub rm { 
	my $c=shift;
	my $schema = $c->stash->{schema};

	for my $page_path ( @ARGV ){
        	my ( $path_pages, $proto_pages ) = $schema->resultset('Page')->path_pages( $page_path );

	        my $page =      @$proto_pages > 0
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
		else {
			print "$page_path doesn't seem to exist"
		}
		$page->delete;
	}
}
sub import_path : Help('file-or-directory  [--file_prefix=removed] [---into=added]  import shit in directory to wiki
		import_path /home/me/wiki/stuff --into=/wiki --file_prefix=/home/me/wiki/stuff
			/home/me/wiki/stuff/pagename -> /wiki/pagename
		import_path foo bar --into=/old-things
			./foo/page 	   -> old-things/foo/page
			./bar/another_page -> old-things/bar/another_page
') {
	my $c=shift;
	my $schema = $c->stash->{schema};
	my $page_prefix = $c->options->{into} || '';
	my $file_prefix = $c->options->{file_prefix} || '';
	my $index_name  = $c->options->{index} || 'index';
	$page_prefix .= '/' unless $page_prefix =~ m{/^};

	my %handler_for = (
		pod => sub { join "\n\n","{{pod}}", @_ , "{{end}}" },
		html => sub { },
		pm => sub { warn "skipping it", next },
	);

	my $started = time;
	my @paths = @{ $c->argv || [] };

	while (defined(my $path = shift @paths) ) {
	        print "$path ";

		#NB: catches on fire with spaces in dir names
		unshift @paths, glob("$path/*") and print ": (recursing)\n" and next if -d $path;
		
		# find extension, strip prefix...
		my $extension = '';
	 	   $extension  = $1 if (my $page_name = $path) =~  s/[.]([^.]+)$//;
					   $page_name =~ s/^$file_prefix//;
		use File::Basename;
		# /path/index -> /path/
		$page_name =~ s/$index_name$// if basename($page_name) eq $index_name;
		my $page_path  = $page_prefix . $page_name;

		$page_path =~ s{/+}{/}g;

		print "-> $page_path :";


		my ( $path_pages, $proto_pages ) = $schema->resultset('Page')->path_pages( $page_path );
		my $date = DateTime->from_epoch( epoch  =>  10 * 60 * 60 + $started + -M $path );

		my $content = do { local (@ARGV, $/) = $path; <> } || ''; 
		
		print preview( do {(my $copy=$content) =~ s/(\s+)/ /g; $copy} , 80) ;
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
		$page->update_content(
			creator 	=> 'c/,,\\',
			body 		=> (exists $handler_for{ $extension }  
 						? $handler_for{ $extension } -> ($content)
						: $content 
						) || '',
			precompiled 	=> '',  # MojoMojo will re-compile it
			release_date    => $date,
			created         => $date,
			status 		=> 'released'
		);
			
			
		print "(" . $date->ymd , " at " ,$date->hms,  " Done.\n";
	}
}

sub find    : Help('<kinda like find(1)>') {
}

sub touch   : Help('path    create page') {
		my $c= shift;


	my $schema = $c->stash->{schema};
	my $content = ''; # perhaps a "this page intentionally left blank" type message?
	for my $page_path (@ARGV) { 

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
            );
            $page = $path_pages->[-1];
	}

	# Get the lastest/requested content version of the page
	my $page_content= $schema->resultset('Content')->find(
	    {
		page    => $page->id,
		version => $page->content_version,
	    }
	);

	$page->update_content(
		creator 	=> 'c/,,\\',
		body 		=> $content,
	    	precompiled 	=> '',  # MojoMojo will re-compile it
	);
		
		
	print "$page_path: Created.";
	}
}

sub edit    : Help('<page> @rev -i   $EDITOR a page, starting at @rev (-i to update @rev, saved a new revision otherwise)' ) { 
		my $c= shift;
	my ($page_path) = shift @ARGV;

	my ($starting_revision) = map {/\@(\d+)/ ? $1  : undef } @ARGV ;
	my ($inplace) = $c->options->{i} || 0;

	my $schema = $c->stash->{schema};

	my ( $path_pages, $proto_pages ) = $schema->resultset('Page')->path_pages( $page_path );

	
    my $page = 
          @$proto_pages > 0
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
sub replace : Help('page, [filename|-] page must exist')  { 
	my $c=shift;
	my ($page_path, $filename_content) = @ARGV;

    die "USAGE: $0 replace /path/to/page filename " if !$page_path;
    die "USAGE: $0 replace /path/to/page filename " if !$filename_content ;



	my $schema = $c->stash->{schema};

	my ( $path_pages, $proto_pages ) = $schema->resultset('Page')->path_pages( $page_path )
	    or die "Can't find page $page_path\n";

	if (scalar @$proto_pages) {
	    die "One or more pages at the end do(es) not exist: ",
		(join ", ", map { $_->{name_orig} } @$proto_pages), "\n";
	}

	# Get the lastest content version of the page
	my $page = $path_pages->[-1];
	my $page_content_rs = $schema->resultset('Content')->search(
	    {
		page    => $page->id,
		version => $page->content_version,
	    }
	);
	die "More than one 'last version' for page <$page_path>. The database may be corrupt.\n"
	    if $page_content_rs->count > 1;
	my $page_content = $page_content_rs->first;    

	open my $file_content, '<:utf8', $filename_content or die $!;
	my $content; {local $/; $content = <$file_content>};

	print "Are you sure you want to replace\n",
	    preview($page_content->body, 300),
	    "\nwith\n",
	    preview($content, 300),
	    "\n? ('yes'/anything else): ";

	my $answer = <STDIN>; chomp $answer;
	if ($answer eq 'yes') {
	    $page_content->update( 
		{
		    body => $content,
		    precompiled => '',  # this needs to be blanked so that MojoMojo will re-compile it
		}
	    );
	    print "Done.\n";
	} else {
	    print "Aborted.\n";
	    exit 1;
	}
}
