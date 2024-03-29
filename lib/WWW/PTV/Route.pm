package WWW::PTV::Route;

use strict;
use warnings;

use HTML::TreeBuilder;
use Scalar::Util qw(weaken);
use Carp qw(croak);

our $VERSION	= '0.01';
our @ATTR	= qw(	id direction_out direction_in direction_out_link direction_in_link
			description_out description_in operator operator_ph );

our %DAY	= ( weekday => 'T0', sat => 'T2', sun => 'UJ' );

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

	$args{ua} ? weaken( $self->{ua} = $args{ua} ) : croak 'Mandatory argument ua not supplied';

        return $self
}

sub get_inbound_tt { 
	my $self	= shift;
	$self->__get_tt( 'in', @_ ) 
} 

sub get_outbound_tt { 
	my $self	= shift;
	$self->__get_tt( 'out', @_ ) 
} 

sub __get_tt {
        my( $self, $direction, $schedule ) = @_; 
	return unless $direction =~ /(in|out)/;
	$schedule ||= 'weekday';
	return unless $schedule =~ /weekday|sat|sun/;

        print "$self->{direction_out_link}&itdLPxx_selWDType=$DAY{ $schedule }\n\n";
        my $tt = $self->__request( ( $direction eq 'out' ? $self->{direction_out_link} : $self->{direction_in} ) 
					. "&itdLPxx_selWDType=$DAY{ $schedule }" );
	my $t = HTML::TreeBuilder->new_from_content( $tt );

	for ( $t->look_down( _tag => 'meta' ) ) {
		if( $_->attr( 'http-equiv' ) eq 'refresh' ) {
			(my $url = $_->attr( 'content' ) ) =~ s/^.*url=//;
			$url .= '&itdLPxx_scrollOffset=118';
			#print "Getting: $url\n";
			$t = HTML::TreeBuilder->new_from_content( $self->__request( "http://tt.ptv.vic.gov.au/tt/$url" ) );
			last
		}
	}
	
	my $dates	= $t->look_down( _tag => 'select', name => 'itdLPxx_selWDType' );
	my %HAVE_DAY	= map { $_->attr( 'value' ) => 1 } $dates->look_down( _tag => 'option' );
	exists $HAVE_DAY{$DAY{ $schedule } } or return;
	$tt = $t->look_down( _tag => 'img', title => 'Expand' );
	#( $tt = $t->look_down( _tag => 'img', title => 'Expand' )->attr( 'onclick' ) ) =~ s/^.*\('//;

	if ( $tt ) {
		( $tt = $tt->attr( 'onclick' ) ) =~ s/^.*\('//;
		$tt =~ s/'.*$//;
		$t = HTML::TreeBuilder->new_from_content( $self->__request( "http://tt.ptv.vic.gov.au/tt/$tt" ) )
	}

	$t = $t->look_down( _tag => 'div', id => qr/tt(Bus|Tram|Train)/ );
	my @stops = $t->look_down( _tag => 'div', class => qr/^ma_stop/ );
	my @stop_names = map { $_->as_text } @stops;
	my @stop_links = map { my ($r) = $_->look_down( _tag => 'a' )->attr( 'href' ) =~ /.*\/(\d*$)/ } @stops;
	my @stop_times;

	foreach my $t ( $t->look_down( _tag => 'div', class => qr/^ttBodyN?TP$/ ) ) {
		#my @s = map { $_->as_text } $t->look_down( _tag => 'span' );
		my @s;

		foreach my $t ( $t->look_down( _tag => 'span' ) ) {
			my ( $h, $m ) = split /:/, $t->as_text;
			push @s, $h and next if $h !~ /\d/;
			my $is_pm = $t->look_down( _tag => 'b' );

			push @s, ( $h == 12 
					? ( $is_pm ? "$h:$m" : "00:$m" )
					: ( $is_pm ? $h + 12 .":$m" : "$h:$m" )
				);
		}

		push @stop_times, [ @s ]
	}

	my @res;
	my $c = 0;

	for ( @stop_links ) {
		#print "id = $stop_links[$c]\nname = $name\n";
		my $res = { 	id	=> $stop_links[ $c ],
				name	=> $stop_names[ $c ],
				times	=> $stop_times[ $c ] };
		push @res, $res;
		$c++
	}

	return @res;
	return @stop_times;
	return @stop_links
}

sub __request {
        my($self,$uri)  = @_; 
        my $res = ( $uri !~ /^http:/
                ? $self->{ua}->get( $self->{uri} . $uri )
                : $self->{ua}->get( $uri ) );

	return $res->content if $res->is_success;
	croak 'Unable to retrieve content: ' . $res->status_line
}

=head1 NAME

WWW::PTV::Route - Perl class for Public Transport Victoria (PTV) routes

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use WWW::PTV::Route;

    my $foo = WWW::PTV::Route->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS


=head1 AUTHOR

Luke Poskitt, C<< <ltp at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-ptv-route at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-PTV-Route>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::PTV::Route


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-PTV-Route>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-PTV-Route>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-PTV-Route>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-PTV-Route/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Luke Poskitt.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of WWW::PTV::Route
