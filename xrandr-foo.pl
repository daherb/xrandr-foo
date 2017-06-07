#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

my @lines = split /\n/, `xrandr`;
shift @lines; ## ignoring the screen line


my $current_output = "";
my %resolutions;
my @outputs; # avoids problems with the order
my $windowmanager = undef;

sub get_resolutions
{
    for my $l (@lines)
    {
	if ($l =~ /disconnected/)
	{
	}
	elsif ($l =~ /connected/)
	{
	    $l =~ /^(.+?) /;
	    $current_output = $1;
	    push @outputs,$current_output;
	    $resolutions{$current_output}=[];
	}
	else
	{
	    $l =~ /(\d+x\d+) /;
	    
	    push @{$resolutions{$current_output}},$1;
	}
    }
}

sub null
{
    return ((scalar @_ == 0) or ($_[0] eq ''));
}

sub union
{
    my %tmp;
    foreach my $a (@_)
    {
	foreach my $e (@$a)
	{
	    $tmp{$e} = 1;
	}
    }
    return keys %tmp;
}

sub is_in 
{
    my $e = shift @_;
    foreach my $es (@_)
    {
	return 1 if ($e eq $es);
    }
    return 0;
}

sub intersect {
    my @tmps;
    my $universe = shift @_;
    foreach my $a (@_)
    {
	foreach my $e (@$a)
	{
	    if (is_in $e, @$universe)
	    {
		my $tmp = $e;
		push @tmps, $tmp;
	    }
	}
    }
    return @tmps;
}

sub turn_all_off {
    my $command = "xrandr ";
    foreach my $o (@outputs)
    {
	$command = "$command --output $o --off "
    }
    print "$command\n";
    system($command);
}

sub do_mirror_max
{
    turn_all_off;
    # ignore marker element
    shift @_;
    # check if the other parameters exist and make sense
    if (scalar(@_) > 0 && $_[0] ne '')
    {
	@outputs = @_;
    }
    my @common_resolutions = intersect values %resolutions;
    my $max_resolution = shift @common_resolutions;
    my $main_output = shift @outputs;
    my $command = "xrandr --output $main_output --mode $max_resolution ";
    foreach my $o (@outputs)
    {
	$command = "$command --output $o --mode $max_resolution --same-as $main_output "
    }
    print "Set to maximum common resolution $max_resolution\n";
    $command = "$command && pkill -SIGHUP $windowmanager" if (defined $windowmanager);
    print "$command\n";
    system($command);
    exit;
}

sub do_along_max
{
    turn_all_off;
    # ignore marker element
    shift @_;
    # check if the other parameters exist and make sense
    if (scalar(@_) > 0 && $_[0] ne '')
    {
	@outputs = @_;
    }
    my $previous_output = shift @outputs;
    my $resolution = ${$resolutions{$previous_output}}[0];
    my $command = "xrandr --output $previous_output --mode $resolution ";
    foreach my $o (@outputs)
    {
	$resolution = ${$resolutions{$o}}[0];
	$command = "$command --output $o --mode $resolution --right-of $previous_output ";
	$previous_output = $o;
    }
    $command = "$command && pkill -SIGHUP $windowmanager" if (defined $windowmanager);
    print "$command\n";
    system($command);
    exit;
}

sub do_list
{
    print (join ' ',@outputs ) ;
    print "\n";
    exit 0;
}

sub do_usage
{
    print "Possible options:\n";
    print "--list-outputs\n";
    print "--side-by-side [outputs] - order screens side by side with maximum resolutions per screen\n";
    print "--mirror [outputs] - mirror with maximum common resolution\n";
    print "--wm windowmanager - window manager to restart afterwards with SIGHUP\n\n";
    exit 0;
}

{
    my @side_by_side = (1);
    my @mirror = (1);
    my $list = undef;
    get_resolutions;
    GetOptions ('wm=s{1}' => \$windowmanager,'mirror=s{0,}' => \@mirror, 'side-by-side=s{0,}' => \@side_by_side,'list-outputs' => \$list);
    do_list if (defined $list);
    do_along_max @side_by_side if (@side_by_side != (1));
    do_mirror_max @mirror  if (@mirror != (1));
    do_usage;
 }
