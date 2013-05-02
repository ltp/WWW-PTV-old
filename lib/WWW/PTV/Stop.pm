package WWW::PTV::Stop;

use strict;
use warnings;

use Carp qw(croak);

our @ATTR = qw(		address bicycles_cage bicycles_lockers bicycles_racks car_parking 
			escalator feedback_phone fn_org hearing_loop id latitude lifts lighting 
			locality lockers longitude lost_property_phone municipiality 
			municipiality_id myki_checks myki_machines postcode public_phone 
			public_toilet routes seating stairs station_phone tactile_paths 
			taxi_rank transport_type vline_bookings waiting_area_indoor 
			waiting_area_sheltered wheelchair_accessible );

foreach my $attr ( @ATTR ) {
	{
		no strict 'refs';
		*{ __PACKAGE__ .'::'. $attr } = sub {
			my( $self, $val ) = @_;
			$self->{$attr} = $val if $val;
			return $self->{$attr}
		}
	}
}

sub new {
	my( $class, %args ) = @_;
	my $self = bless {}, $class;
	$args{id} or croak 'Constructor failed: mandatory id argument not supplied';

	foreach my $attr ( @ATTR ) { $self->{$attr} = $args{$attr} }

	return $self
}

1;
