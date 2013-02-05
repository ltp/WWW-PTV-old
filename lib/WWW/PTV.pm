package WWW::PTV;

use warnings;
use strict;

use LWP;
use WWW::Mechanize;
use HTML::TreeBuilder;
use Carp qw(croak);
use WWW::PTV::Stop;
use WWW::PTV::Route;

=head1 NAME

WWW::PTV - Perl interface to Public Transport Victoria (PTV) Website

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use WWW::PTV;

    my $ptv = WWW::PTV->new;
    
=head1 METHODS

=cut

our $VERSION = '0.01';

sub __request {
	my($self,$uri)	= @_;
	my $res = ( $uri !~ /^http:/
		? $self->{ua}->get( $self->{uri} . $uri )
		: $self->{ua}->get( $uri ) );
	$res->is_success and return $res->content;
	croak 'Unable to retrieve content: ' . $res->status_line
}

sub __tl_request {
	my ($self, $res)= @_;
	my $r		= $self->__request( $res );
	my $t 		= HTML::TreeBuilder->new_from_content( $r );
	$t		= $t->look_down( _tag => 'select', id => 'MainLineId' );
	my @routes	= $t->look_down( _tag => 'option' );
	return my %routes	= map { $_->attr( 'value' ) => $_->as_text } grep { $_->attr( 'value' ) != -1 } @routes
}

=head2 new

Constructor method - creates a new WWW::PTV object. 

=cut

sub new {
	my($class,%args)= @_;
	my $self 	= bless {}, $class;
	$self->{uri} 	= 'http://' . ( defined $args{uri} ? $args{uri} : 'ptv.vic.gov.au' ) . '/';
	$self->{ua}	= LWP::UserAgent->new;
	$self->{ua}->agent("Mozilla/5.0");
	$self->{tree}	= HTML::TreeBuilder->new;
	return $self	
}

=head2 get_metropolitan_bus_routes

Returns a hash containing all metropolitan bus routes indexed by the bus route ID.

B<Please note> that the bus route ID is not the same as the bus route ID that may be
used to identify the service by the service operator - the ID used in this module refers
to the unique ID assigned to the route within the context of the PTV website.

	my %routes = $ptv->get_metropolitan_bus_routes;
	map { printf( "%-6s: %-50s\n", $_, $routes{ $_ } } sort keys %routes;

	# Prints a list of all metropolitan bus route IDs and names. e.g.
	# 1000  : 814 - Springvale South - Dandenong via Waverley Gardens Shopping Centre, Springvale
	# 1001  : 815 - Dandenong - Noble Park                      
	# 1003  : 821 - Southland - Clayton via Heatherton 
	# ... etc.

=cut

sub get_metropolitan_bus_routes {
	return $_[0]->__tl_request( '/timetables/metropolitan-buses/' )
}

=head2 get_regional_bus_routes

Returns a hash containing all regional bus routes indexed by the bus route ID.

B<Please note> that the bus route ID is the PTV designated ID for the route and not
the service operator ID.

	my %routes = $ptv->get_regional_bus_routes;

	while (( $id, $desc ) = each %routes ) {
		print "$id : $desc\n" if ( $desc =~ /Echuca/ )
	}

	# Prints a list of regional bus routes containing 'Echuca' in the route name - e.g.
	# 1346 : Echuca - Moama (Route 3 - Circular)
	# 1345 : Echuca - Echuca East (Route 2 - Circular)
	# 6649 : Kerang - Echuca via Cohuna (Effective from 18/11/2012)
	# ... etc.

=cut

sub get_regional_bus_routes {
	return $_[0]->__tl_request( '/timetables/regional-buses/' )
}

=head2 get_metropolitan_tram_routes

Returns a hash containing all metropolitan tram routes indexed by the route ID.

B<PLease note> as per the method above, the route ID is the PTV designated route
and not the service operator ID.

=cut

sub get_metropolitan_tram_routes {
	return $_[0]->__tl_request( '/timetables/metropolitan-trams/' )
}

=head2 get_metropolitan_train_routes

Returns a hash containing all metropolitan train routes indexed by the route ID.

B<PLease note> as per the method above, the route ID is the PTV designated route
and not the service operator ID.

=cut

sub get_metropolitan_train_routes {
	return $_[0]->__tl_request( '/timetables/metropolitan-trains/' )
}

=head2 get_route_by_id

	my $route = $ptv->get_route_by_id( 1 );

	print $route->direction_out."\n".$route_description."\n";
	# Prints the outbound route direction ("To Alamein") and a 
	# description of the outbound route

Returns a L<WWW::Route> object for the given route ID representing a transit route.

B<Note that> the route ID is not the service operator route ID, but is the PTV route
ID as obtained from one of the other methods in this class.

See the L<WWW::Route> page for more detail.

=cut

sub get_route_by_id {
	my( $self, $id )= @_;
	$id or return "Mandatory parameter id not given";
	my $r 		= $self->__request( "/route/view/$id" );
	my $t		= HTML::TreeBuilder->new_from_content( $r );
	my %route	= (id => $id);
	my $r_link	= $t->look_down( _tag => 'div', class => 'timetablesInner' );
	( $route{direction_out}, $route{direction_in} ) 
			= $r_link->look_down( _tag => 'a' );

	( $route{direction_out_link}, $route{direction_in_link} ) 
			= map { $_->attr( 'href' ) } $r_link->look_down( _tag => 'a' );

	( $route{direction_out}, $route{direction_in} ) 
			= map { $_->as_text } ( $route{direction_out}, $route{direction_in} );

	$r_link		= $t->look_down( _tag => 'div', class => 'routeDescription' );
	( $route{description_out}, $route{description_in} ) 
			= map { $_->as_text } $r_link->look_down( _tag => 'p' );
	my $operator 	= $t->look_down( _tag => 'div', class => 'operator' )->as_text;
	( $route{operator}, $route{operator_ph} ) 
			= $operator =~ /Operator:(.*?)Contact:(.*?)Visit/;
	$route{ua} = $self->{ua};

	return WWW::PTV::Route->new( %route )
}



sub get_stop_by_id {
	my( $self, $id )= @_;
	$id or return "Mandatory parameter id not given";
	my $r				= $self->__request( "/stop/view/$id" );
	my $t				= HTML::TreeBuilder->new_from_content( $r );
	my %stop			= (id => $id );
	$stop{fn_org}			= $t->look_down( _tag => 'h1',   class => 'fn org' )->as_text;
	$stop{fn_org}	 		=~ /\w+/ or return "Stop id ($id) appears to be invalid";
	$stop{transport_type} 		= $t->look_down( _tag => 'div',   class => 'transportType' )->as_text;
	my $r_root			= $t->look_down( _tag => 'div', class => 'lineInformationInner' );
	my $s_root			= $t->look_down( _tag => 'div', class => 'stopProfileInner' );
	$stop{address}			= $s_root->look_down( _tag => 'span', class => 'street-address' )->as_text;
	$stop{locality}			= $s_root->look_down( _tag => 'span', class => 'locality' )->as_text;
	$stop{postcode}			= $s_root->look_down( _tag => 'span', class => 'postal-code' )->as_text;
	my $municipiality		= $s_root->look_down( _tag => 'a' );
	$stop{municipiality}		= $municipiality->as_text;
	$stop{municipiality_id}		= (split "\/", $municipiality->attr( 'href' ))[-1];
	$stop{latitude}			= $t->look_down( _tag => 'span', class => 'latitude' )->as_text;
	$stop{longitude}		= $t->look_down( _tag => 'span', class => 'longitude' )->as_text;

	foreach my $row ( $s_root->look_down( _tag => 'tr' ) ) {
		my ($var,$val) = $row->content_list;
		( $var = lc $var->as_text ) =~ s/\s/_/g;
		next if $var =~ /^address$/;
		$var =~ s/\///g;
		$var =~ s/_\(.*\)//g;
		my @subs = $val->look_down( _tag => qr/d(t|d)/ );

		if ( @subs ) {
			for ( my $i=0;$i<@subs;$i+=2 ) {
				(my $svar = lc $subs[$i]->as_text) =~ tr/ /_/;
				$svar =~ s/://g;
				$svar =~ s/\///g;
				$svar =~ s/_\(.*\)//g;
				$stop{"$var\_$svar"} = $subs[$i+1]->as_text;
			}
		}
		else {
			$stop{$var} = $val->as_text
		}
		print "$var = ",$val->as_text,"\n";
	}

	%{$stop{routes}} = map { 
			( my ($r) = $_->attr('href') =~ /.*\/(\d*$)/ ) => $_->as_text 
		} $r_root->look_down( _tag => 'a', href => qr/^\/route/ );

	$stop{ua} = $self->{ua};
	return WWW::PTV::Stop->new( %stop );
}

=head1 AUTHOR

Luke Poskitt, C<< <ltp at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-ptv at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-PTV>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::PTV


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-PTV>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-PTV>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-PTV>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-PTV/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Luke Poskitt.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
