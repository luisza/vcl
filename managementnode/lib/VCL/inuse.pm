#!/usr/bin/perl -w
###############################################################################
# $Id: inuse.pm 1670472 2015-03-31 20:34:45Z jfthomps $
###############################################################################
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

=head1 NAME

VCL::inuse - Perl module for the VCL inuse state

=head1 SYNOPSIS

 use VCL::inuse;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my $request_info = get_request_info->($request_id);

 # Set the reservation ID in the hash
 $request_info->{RESERVATIONID} = $reservation_id;

 # Create a new VCL::inuse object based on the request information
 my $inuse = VCL::inuse->new($request_info);

=head1 DESCRIPTION

 This module supports the VCL "inuse" state. The inuse state is reached after
 a user has made a reservation, acknowledged the reservation, and connected to
 the machine. Once connected, vcld creates a new process which then
 creates a new instance of this module.

 If the "checkuser" flag is set for the image that the user requested,
 this process will periodically check to make sure the user is still
 connected. Users have 15 minutes to reconnect before the machine is
 reclaimed.

 This module periodically checks the end time for the user's request versus
 the current time. If the end time is near, notifications may be sent to the
 user. Once the end time has been reached, the user is disconnected and the
 request and computer are put into the "timeout" state.

=cut

##############################################################################
package VCL::inuse;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw(VCL::Module::State);

# Specify the version of this module
our $VERSION = '2.4.2';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use POSIX qw(ceil floor strftime);
use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 process

 Parameters  : none
 Returns     : exits
 Description : Processes a reservation in the inuse state.

=cut

sub process {
	my $self = shift;
	
	my $request_id              = $self->data->get_request_id();
	my $request_state_name      = $self->data->get_request_state_name();
	my $request_start           = $self->data->get_request_start_time();
	my $request_end             = $self->data->get_request_end_time();
	my $request_forimaging      = $self->data->get_request_forimaging();
	my $request_checkuser       = $self->data->get_request_checkuser();
	my $reservation_id          = $self->data->get_reservation_id();
	my $reservation_count       = $self->data->get_reservation_count();
	my $server_request_id       = $self->data->get_server_request_id();
	my $imagemeta_checkuser     = $self->data->get_imagemeta_checkuser();
	my $is_parent_reservation   = $self->data->is_parent_reservation();
	my $computer_id             = $self->data->get_computer_id();
	my $computer_short_name     = $self->data->get_computer_short_name();
	
	my $connect_timeout_seconds = $self->os->get_timings('reconnecttimeout');
	
	# Check if reboot operation was requested
	if ($request_state_name =~ /reboot/) {
		if ($self->os->can('reboot')) {
			if (!$self->os->reboot()) {
				notify($ERRORS{'CRITICAL'}, 0, "user requested reboot of $computer_short_name failed");
			}
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "'$request_state_name' operation requested, " . ref($self->os) . " does not implement a 'reboot' subroutine");
		}
		
		$self->state_exit('inuse', 'inuse');
	}
	
	# Check if server reservation has been modified
	if ($request_state_name =~ /servermodified/) {
		if (!$self->os->add_user_accounts()) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to update server access");
      }
		$self->state_exit('inuse', 'inuse');
	}
	
	# Make sure connect timeout is long enough
	# It has to be a bit longer than the ~5 minute period between inuse checks due to cluster reservations
	# If too short, a user may be connected to one computer in a cluster and another inuse process times out before the connected computer is checked
	my $connect_timeout_minutes = ceil($connect_timeout_seconds / 60);
	
	# Connect timeout must be in whole minutes
	$connect_timeout_seconds = ($connect_timeout_minutes * 60);
	
	my $now_epoch_seconds = time;
	
	my $request_start_epoch_seconds = convert_to_epoch_seconds($request_start);
	my $request_end_epoch_seconds = convert_to_epoch_seconds($request_end);
	
	my $request_remaining_seconds = ($request_end_epoch_seconds - $now_epoch_seconds);
	my $request_remaining_minutes = floor($request_remaining_seconds / 60);
	
	my $request_duration_seconds = ($request_end_epoch_seconds - $request_start_epoch_seconds);
	my $request_duration_hours = floor($request_duration_seconds / 60 / 60);
	
	my $end_time_notify_seconds = $self->os->get_timings('general_end_notice_first');
	my $end_time_notify_minutes = floor($end_time_notify_seconds / 60);
	
	my $now_string               = strftime('%H:%M:%S', localtime($now_epoch_seconds));
	my $request_end_string       = strftime('%H:%M:%S', localtime($request_end_epoch_seconds));
	my $request_remaining_string = strftime('%H:%M:%S', gmtime($request_remaining_seconds));
	my $end_time_notify_string   = strftime('%H:%M:%S', gmtime($end_time_notify_seconds));
	my $connect_timeout_string   = strftime('%H:%M:%S', gmtime($connect_timeout_seconds));
	
	# Check if near the end time
	# Compare remaining minutes to connect timeout minutes in case this is > 15 minutes
	if ($request_remaining_minutes <= ($end_time_notify_minutes + 6)) {
		# Only 1 reservation needs to handle the end time countdown
		if (!$is_parent_reservation) {
			notify($ERRORS{'OK'}, 0, "request end time countdown handled by parent reservation, exiting");
			$self->state_exit();
		}
		
		my $sleep_seconds = ($request_remaining_seconds - $end_time_notify_seconds);
		if ($sleep_seconds > 0) {
			my $sleep_string = strftime('%H:%M:%S', gmtime($sleep_seconds));
			notify($ERRORS{'OK'}, 0, "request end time is near, sleeping for $sleep_seconds seconds:\n" .
				"current time     : $now_string\n" .
				"request end time : $request_end_string\n" .
				"remaining time   : $request_remaining_string\n" .
				"notify time      : $end_time_notify_string\n" .
				"sleep time       : $sleep_string"
			);
			sleep $sleep_seconds;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "request notify end time has passed:\n" .
				"current time           : $now_string\n" .
				"request end time       : $request_end_string\n" .
				"remaining time         : $request_remaining_string\n" .
				"notify time            : $end_time_notify_string"
			);
		}
		
		# Loop for $end_time_notify_minutes regardless of how much time is actually left
		# The time until request.end may be short if vcld wasn't running
		# This gives the user notice that the request is ending
		for (my $iteration = 0; $iteration <= $end_time_notify_minutes; ++$iteration) {
			$request_remaining_minutes = ($end_time_notify_minutes - $iteration);
			notify($ERRORS{'OK'}, 0, "minutes until end of end of request: $request_remaining_minutes");
			
			# Check if user deleted the request
			$self->state_exit() if is_request_deleted($request_id);
			
			# Check if this is an imaging request, causes process to exit if state or laststate = image
			$self->check_imaging_request();
			
			# Get the current request end time from the database
			my $current_request_end = get_request_end($request_id);
			my $current_request_end_epoch_seconds = convert_to_epoch_seconds($current_request_end);
			
			# Check if the user extended the request
			if ($current_request_end_epoch_seconds > $request_end_epoch_seconds) {
				notify($ERRORS{'OK'}, 0, "user extended request, end time: $request_end --> $current_request_end, returning request to inuse state");
				$self->state_exit('inuse', 'inuse');
			}
			
			# Notify user when 5 or 10 minutes remain
			if ($request_remaining_minutes == 5 || $request_remaining_minutes == 10) {
				$self->_notify_user_disconnect($request_remaining_minutes);
			}
			
			if ($iteration < $end_time_notify_minutes) {
				notify($ERRORS{'OK'}, 0, "sleeping for 60 seconds");
				sleep 60;
			}
		}
		
		# Notify user - endtime and image capture has started
		$self->_notify_user_request_ended();
		
		# Initiate auto-capture process if this is an imaging request and not a cluster reservation
		if ($request_forimaging && $reservation_count == 1) {
			notify($ERRORS{'OK'}, 0, "initiating image auto-capture process");
			if (!$self->_start_imaging_request()) {
				notify($ERRORS{'CRITICAL'}, 0, "failed to initiate image auto-capture process, changing request and computer state to maintenance");
				$self->state_exit('maintenance', 'maintenance');
			}
			#Successful, cleanly exit with no state change
			$self->state_exit()
		}
		
		$self->state_exit('timeout', 'timeout', 'EOR');
	}
	
	# If duration is greater than 24 hours perform end time notice checks
	if ($is_parent_reservation && $request_duration_hours >= 24) {
		notify($ERRORS{'DEBUG'}, 0, "checking end time notice interval, request duration: $request_duration_hours hours, parent reservation: $is_parent_reservation");
		# Check end time for a notice interval - returns 0 if no notice is to be given
		my $notice_interval = check_endtimenotice_interval($request_end);
		if ($notice_interval) {
			$self->_notify_user_endtime($notice_interval);
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "skipping end time notice interval check, request duration: $request_duration_hours hours, parent reservation: $is_parent_reservation");
	}
	
	# Check if the computer is responding to SSH
	# Skip connection checks if the computer is not responding to SSH
	# This prevents a reservatino from timing out if the user is actually connected but SSH from the management node isn't working
	if (!$self->os->is_ssh_responding()) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name is not responding to SSH, skipping user connection check");
		$self->state_exit('inuse', 'inuse');
	}
	
	# Update the firewall if necessary - this is what allows a user to click Connect from different locations
	if ($self->os->can('firewall_compare_update')) {
		$self->os->firewall_compare_update();
	}
	
	# Compare remaining minutes to connect timeout
	# Connect timeout may be longer than 15 minutes
	# Make sure connect timeout doesn't run into the end time notice
	if ($request_remaining_minutes < ($connect_timeout_minutes + $end_time_notify_minutes)) {
		notify($ERRORS{'DEBUG'}, 0, "skipping user connection check, connect timeout would run into the end time notice stage:\n" .
			"current time     : $now_string\n" .
			"request end time : $request_end_string\n" .
			"remaining time   : $request_remaining_string\n" .
			"notify time      : $end_time_notify_string\n" . 
			"connect timeout  : $connect_timeout_string"
		);
		$self->state_exit('inuse', 'inuse');
	}
	
	# TODO: fix user connection checking for cluster requests
	if ($reservation_count > 1) {
		notify($ERRORS{'OK'}, 0, "skipping user connection check for cluster request");
		$self->state_exit('inuse', 'inuse');
	}
	
	# Insert reconnecttimeout immediately before beginning to check for user connection
	# Web uses timestamp of this to determine when next to refresh the page
	# Important because page should refresh as soon as possible to reservation timing out
	insertloadlog($reservation_id, $computer_id, "reconnecttimeout", "begin reconnection timeout ($connect_timeout_seconds seconds)");
	
	# Check to see if user is connected. user_connected will true(1) for servers and requests > 24 hours
	my $user_connected = $self->code_loop_timeout(sub{$self->user_connected()}, [], "waiting for user to connect to $computer_short_name", $connect_timeout_seconds, 15);
	
	# Delete the connecttimeout immediately after acknowledgement loop ends
	delete_computerloadlog_reservation($reservation_id, 'connecttimeout');
	
	if (!$user_connected) {
		if (!$imagemeta_checkuser || !$request_checkuser) {
			notify($ERRORS{'OK'}, 0, "never detected user connection, skipping timeout, imagemeta checkuser: $imagemeta_checkuser, request checkuser: $request_checkuser");
		}
		elsif ($server_request_id) {
			notify($ERRORS{'OK'}, 0, "never detected user connection, skipping timeout, server reservation");
		}
		elsif ($request_forimaging) {
			notify($ERRORS{'OK'}, 0, "never detected user connection, skipping timeout, imaging reservation");
		}
		elsif ($reservation_count > 1) {
			notify($ERRORS{'OK'}, 0, "never detected user connection, skipping timeout, cluster reservation");
		}
		elsif ($request_duration_hours > 24) {
			notify($ERRORS{'OK'}, 0, "never detected user connection, skipping timeout, request duration: $request_duration_hours hours");
		}
		elsif (is_request_deleted($request_id)) {
			$self->state_exit();
		}
		else {
			# Update reservation lastcheck, otherwise request will be processed immediately again
			update_reservation_lastcheck($reservation_id);
			
			$self->_notify_user_timeout();
			$self->state_exit('timeout', 'inuse', 'timeout');
		}
	}
	
	$self->state_exit('inuse', 'inuse');
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_endtime

 Parameters  : $request_data_hash_reference, $notice_interval
 Returns     : 1 if successful, 0 otherwise
 Description : Notifies the user how long they have until the end of the
               request. Based on the user configuration, an e-mail message, IM
               message, or wall message may be sent. A notice interval string
               must be passed. Its value should be something like "5 minutes".

=cut

sub _notify_user_endtime {
	my $self = shift;
	my $notice_interval = shift;
	
	# Check to make sure notice interval is set
	if (!defined($notice_interval)) {
		notify($ERRORS{'WARNING'}, 0, "end time message not set, notice interval was not passed");
		return 0;
	}
	
	my $is_parent_reservation = $self->data->is_parent_reservation();
	if (!$is_parent_reservation) {
		notify($ERRORS{'DEBUG'}, 0, "child reservation - not notifying user of endtime");
		return 1;
	}
	
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_login_id                   = $self->data->get_user_login_id();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();
	my $request_forimaging              = $self->check_imaging_request();	
	my $request_id                      = $self->data->get_request_id();
	
	my $message;
	my $subject;
	my $short_message = "You have $notice_interval until the scheduled end time of your reservation. VCL Team";
	
	$message  = <<"EOF";

You have $notice_interval until the scheduled end time of your reservation for image $image_prettyname.

Reservation extensions are available if the machine you are on does not have a reservation immediately following.

To edit this reservation:
-Visit $user_affiliation_sitewwwaddress
-Select Current Reservations

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

	$subject = "VCL -- $notice_interval until end of reservation for $image_prettyname";
	
	# Send mail
	if ($user_emailnotices) {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id email notices enabled - notifying user of endtime");
		mail($user_email, $subject, $message, $user_affiliation_helpaddress);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id email notices disabled - not notifying user of endtime");
	}

	# notify via console
	if ( $self->os->can('notify_user_console') ) {
		if ( $self->os->notify_user_console($short_message) ) {
			notify($ERRORS{'DEBUG'}, 0, "Successfully notified user $user_login_id via console method");
		}
	}
	
	# Send message to machine
	if ($computer_type =~ /blade|virtualmachine/) {
		if ($image_os_type =~ /osx/) {
        # Notify via oascript
        notify_via_oascript($computer_short_name, $user_login_id, $short_message);
     }
	} ## end if ($computer_type =~ /blade|virtualmachine/)
	
	# Send IM
	if ($user_imtype_name ne "none") {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id IM type: $user_imtype_name - notifying user of endtime");
		notify_via_im($user_imtype_name, $user_im_id, $message);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id IM type: $user_imtype_name - not notifying user of endtime");
	}
	
	return 1;
} ## end sub _notify_user_endtime
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_disconnect

 Parameters  : $disconnect_time
 Returns     : boolean
 Description : Notifies the user that the session will be disconnected soon.
               Based on the user configuration, an e-mail message, IM message,
               Windows msg, or Linux wall message may be sent. A scalar
               containing the number of minutes until the user is disconnected
               must be passed as the 2nd parameter.

=cut

sub _notify_user_disconnect {
	my $self = shift;
	my $disconnect_time = shift;
	
	# Check to make sure disconnect time was passed
	if (!defined($disconnect_time)) {
		notify($ERRORS{'WARNING'}, 0, "disconnect time message not set, disconnect time was not passed");
		return 0;
	}
	
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_login_id                   = $self->data->get_user_login_id();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();
	my $is_parent_reservation           = $self->data->is_parent_reservation();
	my $request_forimaging              = $self->check_imaging_request();
	
	my $disconnect_string;
	if ($disconnect_time == 0) {
		$disconnect_string = "0 minutes";
	}
	elsif ($disconnect_time == 1) {
		$disconnect_string = "1 minute";
	}
	else {
		$disconnect_string = "$disconnect_time minutes";
	}
	
	my $short_message;
	my $subject;
	my $message;
	
	if (!$request_forimaging) {
		$message = <<"EOF";

You have $disconnect_string until the end of your reservation for image $image_prettyname, please save all work and prepare to exit.

Reservation extensions are available if the machine you are on does not have a reservation immediately following.

Visit $user_affiliation_sitewwwaddress and select Current Reservations to edit this reservation.

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

		$short_message = "You have $disconnect_string until the end of your reservation. Please save all work and prepare to log off.";
		$subject = "VCL -- $disconnect_string until end of reservation";
	}
	else {
		$short_message = "You have $disconnect_string until the auto capture process is started.";
		$subject = "VCL Imaging Reservation -- $disconnect_string until starting auto capture";
		$message = <<"EOF";

You have $disconnect_string until the end of your reservation for image $image_prettyname. 

At the scheduled end time your imaging reservation will be automatically captured. 

To prevent this auto capture, visit the VCL site $user_affiliation_sitewwwaddress manually start the image creation process.

Please note this auto capture feature is intended to prevent destorying any work you have done to the image.

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

	}
	
	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $user_affiliation_helpaddress);
	}

	# notify via console
	if ( $self->os->can('notify_user_console') ) {
		if ( $self->os->notify_user_console($short_message) ) {
			notify($ERRORS{'DEBUG'}, 0, "Successfully notified user $user_login_id via console method");
		}
	}
	
	# Send IM
	if ($is_parent_reservation && $user_imtype_name ne "none") {
		notify_via_im($user_imtype_name, $user_im_id, $message);
	}
	
	return 1;
} ## end sub _notify_user_disconnect
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_timeout

 Parameters  : none
 Returns     : boolean
 Description : Notifies the user that the session has timed out. Based on the
               user configuration, an e-mail message, IM message, Windows msg,
               or Linux wall message may be sent.

=cut

sub _notify_user_timeout {
	my $self = shift;
	
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_login_id                   = $self->data->get_user_login_id();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();
	my $is_parent_reservation           = $self->data->is_parent_reservation();
	
	my $message = <<"EOF";

Your reservation has timed out due to inactivity for image $image_prettyname.

To make another reservation, please revisit:
$user_affiliation_sitewwwaddress

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

	my $subject = "VCL -- reservation timeout";
	
	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $user_affiliation_helpaddress);
	}
	
	# Send IM
	if ($is_parent_reservation && $user_imtype_name ne "none") {
		notify_via_im($user_imtype_name, $user_im_id, $message);
	}
	
	return 1;
} ## end sub _notify_user_timeout
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_request_ended

 Parameters  : none
 Returns     : boolean
 Description : Notifies the user that the session has ended.
               Based on the user configuration, an e-mail message, IM message,
               Windows msg, or Linux wall message may be sent.

=cut

sub _notify_user_request_ended {
	my $self = shift;
	
	my $request_id                      = $self->data->get_request_id();
	my $request_logid                   = $self->data->get_request_log_id();
	my $request_forimaging              = $self->data->get_request_forimaging();
	my $reservation_count               = $self->data->get_reservation_count();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $reservation_is_parent           = $self->data->is_parent_reservation;
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_standalone                 = $self->data->get_user_standalone();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();
	my $is_parent_reservation           = $self->data->is_parent_reservation();
	my $subject;
	my $message;
	
	if (!$request_forimaging) {
	$subject = "VCL -- End of reservation";
	
	$message = <<"EOF";

Your reservation of $image_prettyname has ended. Thank you for using $user_affiliation_sitewwwaddress.

Regards,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF
	}
	else {
		$subject = "VCL Image Reservation - Auto capture started";
		
		$message = <<"EOF";

Your imaging reservation of $image_prettyname has reached it's scheduled end time.

To avoid losing your work we have started an automatic capture of this image. Upon completion of the 
image capture. You will be notified about the completion of the image capture.

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

	}
	
	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $user_affiliation_helpaddress);
	}
	
	# Send IM
	if ($is_parent_reservation && $user_imtype_name ne "none") {
		notify_via_im($user_imtype_name, $user_im_id, $message);
	}
	
	return 1;
} ## end sub _notify_user_request_ended

#/////////////////////////////////////////////////////////////////////////////

=head2 _start_imaging_request

 Parameters  : none
 Returns     : boolean
 Description : If request is forimaging and times out, this inserts a imaging
               reservation. 

=cut

sub _start_imaging_request {
	my $self = shift;
	
	my $request_id = $self->data->get_request_id();
	
	my $method = "XMLRPCautoCapture";
	my @argument_string = ($method, $request_id);
	my $xml_ret = xmlrpc_call(@argument_string);
	
	# Check if the XML::RPC call failed
	if (!defined($xml_ret)) {
		notify($ERRORS{'WARNING'}, 0, "failed to start imaging request, XML::RPC '$method' call failed");
		return;
	}
	elsif ($xml_ret->value->{status} !~ /success/) {
		notify($ERRORS{'WARNING'}, 0, "failed to start imaging request, XML::RPC '$method' status: $xml_ret->value->{status}\n" .
			"error code $xml_ret->value->{errorcode}\n" .
			"error message: $xml_ret->value->{errormsg}"
		);
		return;
	}
	else {
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
