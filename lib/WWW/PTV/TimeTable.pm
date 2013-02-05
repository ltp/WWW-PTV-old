package WWW::PTV::TimeTable;

# Day codes for itdLPxx_selWDType param
#	Mon-Fri	T0
#	Sat	T2
#	Sun	UJ
use strict;
use warnings;

use Carp qw(croak);

our $VERSION = '0.01';

our @ATTR = qw( route_id direction direction_desc name );

sub new {
	my $self = shift;
	$self = {
		222	=> [ 
		0	=> qw(07:30 08:30 09:30)
	};
	bless $self, $class;
	return $self
}

my $stop = $ptv->get_stop(22200);
my $tt = $stop->get_tt;
print $tt->days;
print $tt->monday;

my $route = $ptv->get_route( 222 );
$route = {
		tt_out		=> WWW::PTV::TimeTable(HASH),
		tt_in		=> WWW::PTV::TimeTable(HASH),
		stops		=> [222 223 224 WWW::PTV::Stop(HASH)],
		
my $tt = $route->get_tt;
$tt->
