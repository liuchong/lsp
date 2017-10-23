#!/usr/bin/perl

# A sub to print the help text as you will see an expect.
sub print_help{
	print "HELP FOR \"lsp\"\n"
	    . "\t\tFind some command matched the given words.\n"
	    . "\nOPTIONS:\n\t\tExcept -h and --help which will print"
	    . " this help text,others will headed\n\t\tby \"/\",whi"
	    . "ch symbol will not appear in a file name without the"
	    . " path of\n\t\tparents directorys with \"/\".\n\n"
	    . "/P\t\tOnly search the path what you given behind.\n"
	    . "/AP\t\tAdd what you given to the search path.\n"
	    . "/s\t\tAlso search /sbin,/usr/sbin,/usr/local/sbin.\n"
	    . "/p\t\tPrint PATH,also print the path after the sbins"
	    . " added if the\n\t\toption /s was given.\n"
	    . "/e\t\tExactly match will be printed while others not.\n"
	    . "/h\t\t\"/h\" take place of \"-h\" as above.\n"
	    . "//help\t\t\"//help\"take place of \"--help\" as above.\n"
	    . "-h,--help\tDisplay this help list.\n";
	exit;
}

# In each dir,this sub will work for you to print a line for each
# matching file,and return ture if find an exact one.
sub find_ls{
    die "\"find_ls\" should not has a 5th arg!\n" if $_[4];
    my $finded;
    if ($_[0] && $_[1] ) {
	my $dir_name = $_[0];
# F**k!
# This part is appearing for the metacharacters-stoping work.
	my $got_name = join "\\.",split/\./,'0' . $_[1] . '0';
	$got_name = join "\\+",split/\+/,$got_name;
	$got_name = join "\\?",split/\?/,$got_name;
	$got_name = join "\\*",split/\*/,$got_name;
	$got_name =~ s/^0(.*)0$/$1/;
	$dir_name = $1 if ($dir_name =~ /(.*)\/$/);
# F**k!
	opendir DIR,$dir_name or warn"**ERROR**: $_[0] :$!\n";
	chdir $dir_name or my $bad_dir = 1;
	foreach my $file_name(readdir DIR) {
	    if ($file_name =~ /$got_name/) {
		if (!$_[2]) {
# While find a matching one,print it an try to show something
# for one to recognize the type of the file.
		    print "  $dir_name/$file_name";
		    print " @" if -l $file_name;
		    print " /" if -d $file_name;
		    print " *" if -x $file_name;
		    print "\n";
# This is a "tmp" number,see below.
		    ++$_[4];
		}
# A total counter for each cmd which you ara finding.
		++$_[3];
	    }
	}
# For NO $_[4],it will be undef each time the sub runs,use it as mark.
	if (!$_[2] && $_[4]) {
	    print "Above is $_[4] matching in \"$dir_name\"\n"
		. "^^^^^\n";
	}
	$finded = 1 if (!$bad_dir &&-e $_[1]);
    }
    $finded;
}


# Get the cmd an the option.
foreach (@ARGV) {
    if (!$mark_P && !$mark_AP) {
	if ($_ =~ /^\//) {
	    if ($_ eq '/P') {
		$mark_P = 1;
	    } elsif ($_ eq '/AP') {
		$mark_AP = 1;
	    } elsif ($_ eq '/s') {
		$mark_s = 1;
	    } elsif ($_ eq '/e') {
		$mark_e = 1;
	    } elsif ($_ eq '/p') {
		$mark_p = 1;
	    } elsif ($_ eq '/h') {
		++$argv_hash{'-h'};
	    } elsif ($_ eq '//help') {
		++$argv_hash{'--help'};
	    } else {
		print "NO SUCH OPTION: $_\n\n";
		print_help();
		die "\n";
	    }
	} elsif ($_ eq '-h' || $_ eq '--help') {
	    print_help();
	} else {
	    ++$argv_hash{$_};
	}
    } else {
	$cur_path = $cur_path . ":" . $_;
    }
}

# Get path,is the /s option is given,add some "sbin" to it.
if (!$mark_P) {
    $cur_path = $cur_path . ":" . $ENV{'PATH'};
    $cur_path = '/sbin:/usr/sbin:/usr/local/sbin:' . $cur_path
	if $mark_s;
}

if ($mark_p || !@ARGV) {
    print "********\n" if @ARGV;
    print "$ENV{'PATH'}\n";
    print "********\n$cur_path\n" if $mark_s;
    print "********\n" if @ARGV;
}

$argv_hash = keys %argv_hash;

foreach $cmd (keys %argv_hash) {
    print "========$cmd========\n" if (keys %argv_hash > 1);
    print "YOU ENTERED $argv_hash{$cmd} \"$cmd\"s,BUT ONLY USE ONCE:\n"
        if ($argv_hash{$cmd} > 1 && (%argv_hash > 1 || !$mark_e));
    %dir_hash = ();
    $counter = 0;
    my %exact_match;
# Above,or %exact_match = (); () should not be {} which will not work.
    $time_counter = 0;
    foreach $this_path (split/:/,$cur_path) {
	if ($this_path eq '.') {
	    $this_path = $ENV{'PWD'}
	} elsif ($this_path) {
	    $this_path = $ENV{'PWD'} . "/" . $this_path
		unless $this_path =~ /^\//;
	}
	$this_path =~ s/(.*)\/$/$1/;
	my $finded = find_ls($this_path,$cmd,$mark_e,$counter)
	    if (++$dir_hash{$this_path} == 1);
	$exact_match{$this_path} = ++$time_counter if $finded;
    }

    if ($counter) {
	print "--------\n^_^ FINDED $counter MATCHING \"$cmd\"! ^_^\n"
	    if !$mark_e;
    } else {
	print "--------\n!!!! NONE MATCHING \"$cmd\" !!!!\n";
    }

    my $using_cmd;
    my $find_using_times = 1;
    %exact_match = reverse %exact_match if %exact_match;
    my @sorted_keys = sort(keys %exact_match);
    foreach (@sorted_keys) {
	$exact_match{$_} =~ s/(.*)\/$/$1/;
	if (!$mark_e) {
	    print "   FIND AN EXACT ONE IN [$exact_match{$_}]:\n";
	} else {
	    print "[$exact_match{$_}]:\n";
	}
	my $exact_cmd = "$exact_match{$_}/$cmd";
	if ($_ == $find_using_times
	    && (-f $exact_cmd || -l $exact_cmd)) {
	    $using_cmd = $exact_cmd;
	}
	system "ls -dl --color=auto $exact_cmd";
	while (-l $exact_cmd) {
	    if ($exact_cmd =~ /(.*\/)(.+)/) {
		$cmd_dir = $1;
	    }
	    $exact_cmd = readlink "$exact_cmd";
	    unless ($exact_cmd =~ /^\/.*/) {
		$exact_cmd = "$cmd_dir$exact_cmd";
	    }
	    while ($exact_cmd =~ /(.*?)\/[.]([.]?)(\/.*)/) {
		my $head = $1;
		$exact_cmd = $head;
		my $end = $3;
		if ($2) {
		    if ($head =~ /(.*)\/.*/) {
			$exact_cmd = $1;
		    }
		}
		$exact_cmd .= $end;
	    }
	    system "ls -dl --color=auto $exact_cmd";
	}
	if (-d $exact_cmd && $_ == $find_using_times) {
	    ++$find_using_times;
	    $using_cmd = undef;
	}
    }
    if ($using_cmd) {
	print "You Are Using:\n";
	system "ls --color=auto $using_cmd";
	print "FILE TYPE : ";
	system "file $using_cmd | awk -F\'$using_cmd: \' \'{print\$2}\'";
    }
    --$argv_hash;
    print "\n" if $argv_hash > 0;
}
