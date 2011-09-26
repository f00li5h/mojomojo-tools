package MojoMojo::CLI;
use App::Cmd::Setup -app;

use base qw[ Class::Accessor::Fast ];

__PACKAGE__->mk_accessors(qw[ _schema _conf _author ]);

sub preview { # {{{
	my $self = shift ; 
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


sub author {
	# who the hell are you?
	my $self = shift;

	return $self->_author if $self->_author;

	# if there's an anon user, use him 
	my $anon = $self->schema->resultset('Preference')->find( { prefkey => 'anonymous_user'} );
	if (defined $anon) { 
		$self->_author(
			$self->schema->resultset('Person')->find( {login => $anon->prefvalue})
		);
	}
	else { 
		$self->_author(
			# likelyu to be anon?!
			$self->schema->resultset('Person')->find({id=>1})
		);
	}
	$self->_author;

}

sub conf {
	my $self = shift;
	return $self->_conf if $self->_conf;
	use Config::JFDI; use Cwd;
	my ($config, $jfdi, $faked_it); 
	{
	    $config = ($jfdi = Config::JFDI->new(
		name => "MojoMojo",
		path => getcwd(),
		))->get;

#	($faked_it,$ENV{MOJOMOJO_CONFIG})=(1,'./MojoMojo.conf'), warn "trying ./MojoMojo.conf",redo
#		if not keys %{$config} and not $faked_it;


	#die "Couldn't read config file, tried " . getcwd() . ' and found: ' . join ", ", $jfdi->found
	#if not keys %{$config} and $faked_it;


	}
	$self->_conf( $config );
}

sub page {
	my $self = shift;
	my $page_path = shift;
	my $schema = $self->schema;

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

	return ($page, $page_content,  $path_pages, $proto_pages);
}

sub schema {
	my ($self) = @_;

	return $self->_schema if $self->_schema;

	require MojoMojo::Schema;
	my $config = $self->conf;

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

	$self->_schema( 
		MojoMojo::Schema->connect($dsn, $user, $pass) or
			die "Failed to connect to database"
	)
}

1
