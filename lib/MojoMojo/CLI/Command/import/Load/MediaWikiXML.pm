
package MojoMojo::CLI::Command::import::Load::MediaWikiXML;
use base qw[ MojoMojo::CLI::Command::import::Component ];

use warnings; use strict;

use constant abstract => 'Load mediawiki stuff from an xml file';

sub opt_spec { 
return (
	['xml-from=s',      'which mediawiki xml file to load from' ],
	['xml-debug',  	    'spew out xml related debug info' ],
	['xml-latest', 'dont load up all revisions of the page' ],
)
}
use Data::Dumper;

sub skip_me {
	my ($self,$c, $opt, $args) = @_;
	return "no file to load from"
		if not exists $opt->{'xml_from'};

	()
}

=head load stuff 
 
	stash -> pages { %name } = {
				id  => something numeric
				title  => %name 
				revisions => [
					{
					}
				]
		}

	revisions:  = {
	}
		

=cut 

sub load { 
	# i hear that MediaWiki::DumpFile is a better choice
	# but everything is tied to the contents being a hash
	# and i don't care either way 

	my ($self,$c, $opt, $args) = @_;

	my $filename = exists $opt->{'xml_from'}
			?  $opt->{'xml_from'}
 			: '-'
			;
	my $ditch_old_revs = exists $opt->{'xml_latest'};
				
	require XML::Simple;  #lol.
	my $document = XML::Simple->new();

	warn "xml-debug: Reading mediawiki xml from '$filename'" 
		if $opt->{'xml_debug'};

	die "can't load '$filename' - it's not a file." if not -f $filename;
	my $content = do { local (@ARGV,$/)=$filename;<>};


	my $struct = $document->XMLin( $content, 
		KeyAttr => { page => '+title'}, #  name key title revision] ],
		# ContentKey => '-content',
		ForceArray => [ qw[ revision page namespace namespaces ] ],
		SuppressEmpty => '',
		#ForceArray => 1,
		NoAttr => 1 # in+out - handy
		
	);

	$c->stash->{pages} = $struct->{page};

	if ($ditch_old_revs) {
		for my $page_name ( keys %{ $c->stash->{pages} } ) { 

		$c->stash->{pages}->{ $page_name }->{ revision }
=  [
$c->stash->{pages}->{ $page_name }->{ revision }->[-1]  
]
		}
	}


	print 'xml-debug: ' . Dumper ($struct) if $opt->{xml_debug};
	# print 'waharblegarble: ' . Dumper ($c->stash);
}

1
