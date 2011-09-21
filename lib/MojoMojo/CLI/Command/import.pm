package MojoMojo::CLI::Command::import;
use MojoMojo::CLI -command;
use strict; use warnings;

use constant {
	abstract	=> "stuff things into the wiki",
	description 	=> "Stuff is ::Load, ::Transform ::Finalise'ed based on arguments ... modules will just 'skip' if they don't like the argumetns... so not configuring one means it'll likely not do anything..."
};

use Module::Pluggable # get stuff from place, turn into a struct
	search_path => __PACKAGE__.'::Load',
	sub_name => 'loaders',
	instantiate => 'new'
	;

use Module::Pluggable # mess with the stuff from ::load
	search_path => __PACKAGE__.'::Transform',
	sub_name => 'transformers'
	;
use Module::Pluggable # do the actual loading ...
	search_path => __PACKAGE__.'::Finalise',
	sub_name => 'finalisers'
	;

sub short_name {
	my $package = __PACKAGE__;
	my $thing = shift || $_;
	$thing = ref $thing if ref $thing;
	$thing =~ s/^${package}::[^:]+//;
	$thing
}

sub opt_spec {
	my $self = shift;
	my @opts;
	for ($self->loaders,$self->finalisers,$self->transformers) {
		next unless $_->can('opt_spec');
		push @opts, [
			$_->can('abstract') ? $_->abstract : short_name
		], $_->opt_spec();
	}
	@opts
}

#sub validate_args { my ($self, $opt, $args) = @_; }

use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors(qw[ 
	stash
]);

sub apply_to_page {
	my ($self, $code, $page) = @_;
	# no page
	return if @_ == 3 and not exists $self->stash->{pages}{$page};

	# apply it to the page 
	$code->( $self->stash->{pages}{$page} ) if @_ == 3;


	$code->( $self->stash->{pages}{ $_ } )
		for keys %{ $self->stash->{pages} };
}


sub execute {
	my ($self, $opt, $args) = @_;
	# use Data::Dumper; warn Dumper \@_;
	$self->stash({
		wiki_info => {},# some meta-data about the wiki, i suppose
		pages => {},	# linkely with /path/name as keys, so it doesn' overwrite
		users => {},	# lineky with names as keys 
	});

	warn "Load: ";
	for ($self->loaders) {
	
		warn "skip " . short_name and next if $_->can('skip_me') and $_->skip_me( $self, $opt, $args);
		next unless $_->can('load');
		warn "run  " , short_name;
		$_->load( $self, $opt, $args);
	}

	warn "Transform: ";
	for ($self->transformers) {
		warn "skip " . short_name and next if $_->can('skip_me') and $_->skip_me( $self, $opt, $args);
		next unless $_->can('transform');
		warn "run  " , short_name;
		$_->transform( $self, $opt, $args);
	}

	warn "Finalise: ";
	for ($self->finalisers) {
		warn "skip " . short_name and next if $_->can('skip_me') and $_->skip_me( $self, $opt, $args);
		next unless $_->can('finalise');
		warn "run  " , short_name;
		$_->finalise( $self, $opt, $args);
	}



}
1

