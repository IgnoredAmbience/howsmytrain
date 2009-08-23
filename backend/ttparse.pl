#!/usr/bin/perl

# http://edwardbetts.com/rail_timetable_parser
# License: GPL 2

use strict;
use warnings;

package Page;

use base 'Class::Accessor';
use Data::Dump 'dump';
use List::MoreUtils 'firstidx';

__PACKAGE__->mk_accessors(qw(num lines text tables row_lines table_num table_note1 table_note2 table_days table_places));

my %incomplete;

my %bank_holiday = (
    "Saturday service operates on Bank Holiday Mondays" => 1,
    "First Capital Connect will run a Saturday service on Bank Holiday Mondays" => 1,
    "For details of Bank Holiday service alterations, please see \\306rst page of this Table" => 1,
    "For details of Bank Holiday service alterations, please see \\306rst page of Table 149" => 1
);

my %font;

sub parse_day {
    my $text = shift;
    my @lines = @{$text->{lines}};
    $lines[0] eq "0 0 Td\n" or die;
    $lines[1] =~ m{^/F\d+_0 1 Tf\n$} or die;
    $lines[2] =~ m{^\((Saturdays|Sundays)\) [\d.]+ Tj\n$} or die dump $text;
    return $1;
}

sub make_html_page {
    my ($self, $location) = @_;
    my $table_num = $self->table_num;
    $self->table_places or return;
    my $place = join " -> ", @{$self->table_places};
    open HTML, ">", "$location/" . $self->num . ".html";
    print HTML <<".";
<html>
<head>
<title>Table $table_num: $place</title>
<style>
body { font-family: arial,sans-serif; font-size: 80% }
</style>
</head>
<body>
<h1>Table $table_num: $place</h1>
.
    foreach my $table (@{$self->tables}) {
        $table->{train_col_headings} or next;
        my @col_headings = @{$table->{train_col_headings}};
        my @stations = @{$table->{stations}};
        print HTML qq(<table>\n<tr>\n<th></th>\n);
        for (@col_headings[$table->{station_col}..$#col_headings]) {
            print HTML qq(<th valign="top">);
            if (defined) {
                print HTML $_->{toc};
                defined $_->{flag} and print HTML "<br>\n$_->{flag}\n";
            }
            print HTML "</th>\n";

        }
        foreach my $station (@stations) {
            print HTML "<tr><td nowrap>";
            if ($station->{name}) {
                print HTML ("&nbsp;" x int ($station->{indent} / 3)), "$station->{name}</td>";
            }
            my $d_or_a = $station->{d_or_a};
            print HTML $d_or_a ? qq(<td>$station->{d_or_a}</td>) : '<td></td>';
            for ($table->{station_col}+1..$#col_headings) {
                my $i = $table->{train_times}[$station->{row}][$_];
                if (defined $i) {
                    my $time;
                    if ($i->{check_headnote}) {
                        $time = '^^';
                    } elsif ($i->{earlier}) {
                        $time = '<-/';
                    } elsif ($i->{later}) {
                        $time = '\->';
                    } elsif (defined $i->{hour}) {
                        defined $i->{min} or die;
                        $time = defined $i->{note}
                            ? "$i->{hour}$i->{note}$i->{min}" 
                            : "$i->{hour}&nbsp;$i->{min}";
                    } else {
                        $time = $i->{note};
                    }
                    $time or die dump $i;
                    print HTML qq(<td align="center">$time</td>\n);
                } else {
                    print HTML "<td></td>\n";
                }
            }

            print HTML qq(</tr>\n);
        }
        print HTML "</tr></table>";
    }
    print HTML <<".";
</body>
</html>
.
    close HTML;
}

sub load {
    my ($class, $filename) = @_;
    my $page_num;
    my (@lines, @text, $text);

    my %skip = ( 230 => 1, 694 => 1, 736 => 1, 737 => 1,  );

    open my $fh, $filename or die "$filename: $!";
    my $pdfMakeFont = 0;
    while (<$fh>) {
        if ($_ eq "pdfMakeFont\n") {
            $pdfMakeFont = 1;
            next;
        }
        if ($pdfMakeFont and m{^/(F\d+)_0 /([^ ]+) [\d.]+ [\d.]+$}) {
            $font{$1} = $2;
        }
        $pdfMakeFont = 0;
        
        $_ eq "%%EndSetup\n" and last;
    }
    my $table_num;
    while (<$fh>) {
        if (/^%%Page: (\d+)/) {
            $page_num = $1;
            next;
        }
        defined $page_num or next;
        $page_num > 89 or next;
        if ($_ eq "pdfEndPage\n") {
            if ($page_num >= 90 and not $skip{$page_num}) {
                my $page = $class->new({
                    num     => $page_num,
                    lines   => \@lines,
                    text    => \@text,
                });
                $page->parse();
                if (defined $page->table_num and defined $table_num and $table_num ne $page->table_num) {
#                    %incomplete and die;
                }
                $table_num = $page->table_num;
#                $page->make_html_page("output");
                if (@{$page->tables}) {
                    my $table_places = defined $page->table_places ? join " -> ", @{$page->table_places} : "undef";
                    print "page: ", $page->num(), ", ", "Table ", $page->table_num, ", ", $page->table_days,
                        ", $table_places, ", scalar @{$page->tables}, " table(s) found\n";
                    my $alt_font;
                    TABLE: for (@{$page->tables}) {
                        foreach (grep defined, @{$_->{train_times}}) {
                            foreach (grep { defined and $_->{font} and not $_->{font} eq "Helvetica" } @$_) {
                                $alt_font = $_->{font};
                                last TABLE;
                                #print dump($_), "\n";
                            }
                        }
                    }
                    if ($alt_font) {
                        print "alt font: $font{$alt_font}\n";
                    }
                }
            }
            @lines = (); @text = ();
            next;
        }
        $page_num >= 90 or next;
        if (/ re$/) {
            /^(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re$/ or die $_;
            push @lines, { x => $1, y => $2, w => $3, h => $4 };
            next;
        }
        if (/^\[(.* [1-9]\d*(\.\d+)?)\] Tm$/) {
            $1 =~ /^  (-?[\d.]+)\ -?[\d.]+\ -?[\d.]+
                    \ (-?[\d.]+)
                    \ ([1-9]\d*(?:\.\d+)?)
                    \ ([1-9]\d*(?:.\d+)?)$/x or die "bad Tm: $1";
            $text = { mul_x => $1, mul_y => $2, 
                          x => $3,     y => $4, lines => [] };
            push @text, $text;
            next;
        }
        if (m{^/F.*_0 1 Tf$} or /^.* T(d|j|Jm)$/) {
            @text or next;
            push @{$text->{lines}}, $_;
            next;
        }
    }
    close $filename;
}

sub parse_above_tables {
    my ($self, $above) = @_;
    my $lines = $above->[0]{lines};
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or die;
    $lines->[2] =~ m{^\(Table\) [\d.]+ Tj\n$} or die dump $lines;
    $lines->[3] =~ m{^-337\.7 TJm\n$} or die;
    $lines->[4] =~ m{^\((\d+[A-Z]?)\) [\d.]+ Tj\n$} or die;
    $self->table_num($1);
    my $i = 1;
    if (@$lines == 10) {
        $lines->[6] =~ m{^\(SHIPPING\) [\d.]+ Tj\n$} or die;
        $lines->[8] =~ m{^\(SERVICES\) [\d.]+ Tj\n$} or die;
        $self->table_note1("SHIPPING SERVICES");
        $lines = $above->[1]{lines};
        (@$lines == 3 or @$lines == 4) or die;
        $lines->[0] eq "0 0 Td\n" or die;
        $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or die;
        $lines->[2] =~ m{^\((Saturdays|Sundays)\) [\d.]+ Tj\n$} or die;
        $self->table_days($1);
        $i = 2;
    } elsif (@$lines == 12) {
        $lines->[6] =~ m{^\(SUMMARY\) [\d.]+ Tj\n$} or die scalar (@$lines), "\n", dump $lines;
        $lines->[8] =~ m{^\(OF\) [\d.]+ Tj\n$} or die scalar (@$lines), "\n", dump $lines;
        $lines->[10] =~ m{^\(SERVICES\) [\d.]+ Tj\n$} or die scalar (@$lines), "\n", dump $lines;
        $self->table_note1("SUMMARY OF SERVICES");
        $lines = $above->[1]{lines};
        (@$lines == 3 or @$lines == 4) or die;
        $lines->[0] eq "0 0 Td\n" or die;
        $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or die;
        $lines->[2] =~ m{^\((Saturdays|Sundays)\) [\d.]+ Tj\n$} or die;
        $self->table_days($1);
        $i = 2;
    } elsif (@$lines == 17) {
        $lines->[6] =~ m{^\(SUMMARY\) [\d.]+ Tj\n$} or die scalar (@$lines), "\n", dump $lines;
        $lines->[8] =~ m{^\(OF\) [\d.]+ Tj\n$} or die scalar (@$lines), "\n", dump $lines;
        $lines->[10] =~ m{^\(SERVICES\) [\d.]+ Tj\n$} or die scalar (@$lines), "\n", dump $lines;
        $self->table_note1("SUMMARY OF SERVICES");
        $lines->[12] =~ m{^\(Mondays\) [\d.]+ Tj\n$} or die;
        $lines->[14] =~ m{^\(to\) [\d.]+ Tj\n$} or die;
        $lines->[16] =~ m{^\((Fridays|Saturdays)\) [\d.]+ Tj\n$} or die;
        $self->table_days("Mondays to $1");
    } elsif (@$lines == 15) {
        $lines->[6] =~ m{^\(SHIPPING\) [\d.]+ Tj\n$} or die;
        $lines->[8] =~ m{^\(SERVICES\) [\d.]+ Tj\n$} or die;
        $self->table_note1("SHIPPING SERVICES");
        $lines->[10] =~ m{^\(Mondays\) [\d.]+ Tj\n$} or die;
        $lines->[12] =~ m{^\(to\) [\d.]+ Tj\n$} or die;
        $lines->[14] =~ m{^\((Fridays|Saturdays)\) [\d.]+ Tj\n$} or die;
        $self->table_days("Mondays to $1");
    } elsif (@$lines == 11) {
        if ($lines->[6] =~ m{^\(SHIPPING\) [\d.]+ Tj\n$}) {
            $lines->[8] =~ m{^\(SERVICES\) [\d.]+ Tj\n$} or die;
            $lines->[10] =~ m{^\(Daily\) [\d.]+ Tj\n$} or die;
            $self->table_note1("SHIPPING SERVICES");
            $self->table_days("Daily");
        } else {
            $lines->[6] =~ m{^\(Mondays\) [\d.]+ Tj\n$} or die dump $lines;
            $lines->[8] =~ m{^\(to\) [\d.]+ Tj\n$} or die;
            $lines->[10] =~ m{^\((Fridays|Saturdays)\) [\d.]+ Tj\n$} or die;
            $self->table_days("Mondays to $1");
        }
    } else {
        @$lines == 6 or die scalar(@$lines), "\n", dump $lines;
        $lines = $above->[1]{lines};
        (@$lines == 3 or @$lines == 4) or die;
        $lines->[0] eq "0 0 Td\n" or die;
        $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or die;
        $lines->[2] =~ m{^\((Saturdays|Sundays)\) [\d.]+ Tj\n$} or die;
        $self->table_days($1);
        $i = 2;
    }
    my $text = $above->[$i];
    if ($text->{x} > 200) {
        $self->table_note2(join " ", map { /^\((.*)\) [\d.]+ Tj\n$/?$1:(); } @{$text->{lines}});
        $text = $above->[++$i];
    }
    $self->parse_title($text);
    $lines = $above->[$i+1]{lines};
    my $a = join " ", map { /^\((.*)\) [\d.]+ Tj\n$/?$1:(); } @$lines;
    if ($bank_holiday{$a}) {
        $self->table_note2($a); 
        $lines = $above->[$i+2]{lines};
    }
    $lines and @$lines or return
    my (@note, @cur);
    @note = ();
    @cur = ();
    shift (@$lines) eq "0 0 Td\n" or die;
    shift (@$lines) =~ m{^/F\d+_0 1 Tf\n$} or die;
    foreach (@$lines) {
        m{^\((.*?)\) [\d.]+ Tj\n$} and do {
            push @cur, $1;
            next;
        };
        m{^-?[\d.]+ TJm\n$} and next;
        $_ eq "0 0 Td\n" and last;
        m{^-?[\d.]+ -?[\d.]+ Td\n$} and do {
            my $cur = join " ", @cur;
            $cur =~ s/\\306/fi/g;
            push @note, $cur;
            @cur = ();
        };
    }
    my $cur = join " ", @cur;
    $cur =~ s/\\306/fi/g;
    push @note, $cur;
    $self->table_note2(\@note);
}

sub parse_title {
    my ($self, $text) = @_;
    ($text->{x} > 41 and $text->{x} < 59) or die dump $text;
    ($text->{y} > 770 and $text->{y} < 804) or die dump $text;
    my $lines = $text->{lines};
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/(F\d+_0) 1 Tf\n$} or die;
    my $place_font = $1;

    my $i = 2;
    my (@places, @cur);
    while (1) {
        $_ = $lines->[$i++];
        unless (defined $_) {
            last;
        };
        if (m{^/(F\d+_0) 1 Tf\n$}) {
            $1 eq $place_font and die;
            @cur or die;
            push @places, join (" ", @cur);
            @cur = ();
            $lines->[$i++] =~ /^\(a\) [\d.]+ Tj\n$/ or die;
            $lines->[$i++] =~ /^-?[\d.]+ -?[\d.]+ Td\n$/ or die dump $lines;
            $lines->[$i++] eq "/$place_font 1 Tf\n" or die dump $lines;
            next;
        }
        if (m{^\((.*)\) [\d.]+ Tj\n$}) {
            push @cur, $1;
            next;
        }
        /(Td|TJm)\n$/ and next;
        die "bad: $_\n", dump $lines;
    }
    push @places, join (" ", @cur);
    @places or die dump $lines;
    $self->table_places(\@places);
}

sub parse_below_tables {
    my ($self, $below) = @_;
    return;
    print scalar(@$below), "\n", dump ($below), "\n";
    shift @$below;
    my $count = grep $_->{x} < 70, @$below;
    $count == 1 or die $count;
}

sub find_day_box {
    my ($self, $y1, $y2) = @_;
    $y1 < $y2 or die;
    my @boxes = grep { $_->{x} > 400
            and $_->{y} > $y1 and $_->{y} < $y2
            and $_->{w} > 20 and $_->{h} > 10 } @{$self->lines};
    @boxes or return;
    my $expect;
    if (@boxes == 1) {
        $expect = "Saturdays";
    } else {
        @boxes == 2 or die dump (\@boxes), "\n";
        $expect = "Sundays";
    }
    my @days;
    foreach my $box (@boxes) {
        my @day = grep {
            $_->{x} > $box->{x} and $_->{x} < ($box->{x} + $box->{w}) and
            $_->{y} > $box->{y} and $_->{y} < ($box->{y} + $box->{h})
        } @{$self->text};
        @day == 1 or die;
        $expect eq parse_day(@day) or die;
    }
    return $expect;
}

sub parse {
    my $self = shift;
    $self->find_tables();

    my $i = 0;

    ($self->tables and @{$self->tables}) or return;
    my $t1 = @{$self->tables}[0];
    $self->parse_above_tables([grep { $_->{y} > $t1->{y1} } @{$self->text}]);
    $self->parse_below_tables([grep { $_->{y} < $self->tables->[-1]{y2} } @{$self->text}]);

    my $day = $self->table_days;

    print "page: $self->{num}\n";

    foreach my $t_num (0..@{$self->tables}-1) {
        print "table: $t_num\n";
        my $t = $self->tables->[$t_num];
        $t or die;
        if ($t_num != 0) {
            my $t_prev = $self->tables->[$t_num-1];
            my $day_box = $self->find_day_box($t->{y2}, $t_prev->{y1});
            $day_box and $day = $day_box;
        }
        $t->{day} = $day;
        my @table_lines = grep in_table($t, $_), @{$self->lines};
        @table_lines or die "can't find table lines on page " . $self->num;
        #@table_lines or die dump $self->{tables};
        $t->{table_lines} = \@table_lines;
#        $t->{row_lines} = [find_row_lines(@table_lines)];
        find_col_lines($t);
        $t->{col_lines} or next;
        $t->{interchange_boxes} = [find_interchange_min_box(@table_lines)];
        $t->{num_of_cols} = @{$t->{col_lines}} + 1;
        $t->{station_col} = find_station_col($t);
        $t->{text} = [grep in_table2($t, $_), @{$self->text}];
        parse_table_text($t);
        parse_train_times($t);
        $i++;
        delete $t->{text};
        find_trains($t);
        my @notes = find_notes($t);
        @notes > 2 and print "note count: ", scalar(@notes), "\n";
        print dump (\@notes), "\n";
    }
}

sub parse_train_times {
    my $table = shift;
    my ($min, $note);
    my @train_times;
    foreach my $row (grep defined, @{$table->{train_times}}) {
        my $row_num = $row->[0]{row};
        foreach my $text (@$row) {
            my $x = $text->{x};
            my @lines = @{$text->{lines}};
            shift (@lines) eq "0 0 Td\n" or die;
            shift (@lines) =~ m{^/(F\d+)_0 1 Tf\n$} or die;
            my $font = $1;
#            print "$1\n";
            if (@lines == 18) {
                my $a = join " ", map { /^\((.*)\) [\d.]+ Tj\n$/?$1:(); } @lines;
                if ($a eq "and at the same minutes past each hour until") {
                    print "$text->{col} $a\n";
                    next;
                }
            }
#            print dump ($text->{lines}), "\n";
            foreach (@lines) {
                if (/^(-?[\d.]+) TJm\n$/) {
                    $x += -$1 * 0.001 * $text->{mul_x};
                    next;
                }
                $_ eq "0 0 Td\n" and next;
                if (m{^([\d.]+) 0 Td\n$}) {
                    $x = $text->{x} + $1 * $text->{mul_x};
                    next;
                }
                if (m{^/(F\d+)_0 1 Tf\n$}) {
                    $font = $1;
                    next;
                }
#                if(/^\(AA\) ([\d.]+) Tj\n$/) {
#                    print "AA: ", dump($text), "\n";
#                    exit;
#                    next;
#                }
                if (/^\(\.+\) ([\d.]+) Tj\n$/) {
                    $x += $text->{mul_x} * $1;
                    next;
                }
                if (/^\(([Aut]+)\) ([\d.]+) Tj\n$/) {
                    my $col = find_col($table, $x);
                    $x += $text->{mul_x} * $2;
                    foreach (0..(length $1)-1) { 
                        $train_times[$row_num][$col + $_] ||= {};
                        train_time_add_text($train_times[$row_num][$col + $_], substr($1, $_, 1), $font);
                    }
                    next;
                }

                my ($a, $b) = /^\((\d\d|[a-z])\) ([\d.]+) Tj\n$/ or die "bad: ", dump($text);
                my $col = find_col($table, $x);
                $x += $text->{mul_x} * $b;
                my $col2 = find_col($table, $x);
                $col == $col2 or die "col mismatch: $col != $col2 for $_";
                $train_times[$row_num][$col] ||= {};
                train_time_add_text($train_times[$row_num][$col], $a, $font);
            }
        }
    }
    $table->{train_times} = \@train_times;
}

sub find_notes {
    my $table = shift;
    
    my %notes;
    foreach my $i (@{$table->{train_times}}) {
        foreach my $j (grep {defined and $_->{note}} @$i) {
            $notes{$j->{note}} = 1;
        }
    }
    return sort keys %notes;
}

sub find_trains {
    my $table = shift;
    my @stations = @{$table->{stations}};
    my @col_headings = @{$table->{train_col_headings}};
#    print dump(\@stations), "\n";
    for my $col ($table->{station_col}+1..$#col_headings) {
        my $prev_station;
        my $prev_data;
        my $key;
        my @train;
        foreach my $station (@stations) {
            my $row = $station->{row};
            my $i = $table->{train_times}[$row][$col];
            my $name = $station->{name};
            defined $i or next;
            $key and die;
            if ($i->{later}) {
                $key = $prev_data->{hour} . $prev_data->{min};
#                $incomplete{$key} and die;
                next;
            }
            if ($i->{earlier}) {
                @train and die;
                my $next = $table->{train_times}[$row+1][$col];
                $next or die;
                my $key = $next->{hour} . $next->{min};
                $incomplete{$key} or next;
                $incomplete{$key} or die "key: $key\n", dump (\%incomplete), "\n";
                @train = @{$incomplete{$key}};
                delete $incomplete{$key};
                next;
            }
            if($prev_station and $prev_station eq $name) {
                $station->{d_or_a} eq 'd' or die;
                $train[-1]{d} = $i;
            } else {
                my $d_or_a = $station->{d_or_a};
                $d_or_a or die dump ($station);
                if ($i->{a}) {
                    $d_or_a = 'a';
                }
                if ($i->{d}) {
                    $d_or_a eq 'a' or die;
                    $d_or_a = 'd';
                }
                push @train, { $d_or_a => $i, name => $name, };
            }
            $prev_station = $name;
            $prev_data = $i;
        }
        my %train = (
            stations    => \@train,
            toc         => $col_headings[$col]{toc},
            day         => $table->{day},
        );
        if ($col_headings[$col]{flag}) {
            $train{flag} = $col_headings[$col]{flag}
        }
        if ($key) {
            $incomplete{$key} = \@train;
        } else {
            print dump (\%train), "\n";
        }
    }
}

sub train_time_add_text {
    my ($i, $text, $font) = @_;
    if (length $text == 1) {
        if (not defined $i->{hour}) {
            if ($text eq 'u') {
                $i->{earlier} = 1
            } elsif ($text eq 't') {
                $i->{later} = 1;
            } elsif ($text eq 'A') {
                $i->{check_headnote} = 1;
            } else {
                die "bad train time text: '$text'";
            }
            return;
        }
        defined $i->{hour} or die $text, "\n", dump $i;
        $font{$font} eq 'Helvetica' or die $i->{note_font};
        if ($text eq 'a') {
            $i->{a} = 1;
        } elsif ($text eq 'A') {
            $i->{check_headnote} = 1;
        } elsif ($text eq 'd') {
            $i->{d} = 1;
        } elsif ($text eq 'p') {
            $i->{prev_day} = 1;
        } elsif ($text eq 's') {
            $i->{stop} = 'set down only';
        } elsif ($text eq 'u') {
            $i->{stop} = 'pick_up_only';
        } elsif ($text eq 'x') {
            $i->{stop} = 'on request';
        } elsif ($text =~ /^[a-z]$/) {
            $i->{note} = $text;
        } else {
            die $text;
        }
        return;
    }
    $text =~ /^\d\d$/ or die;
    $i->{defined $i->{hour} ? 'min' : 'hour'} = $text;
    if ($i->{font}) {
        $font eq $i->{font} or die dump [$i, $text, $font];
        delete $i->{font};
        if ($font{$font} eq 'Helvetica-Oblique') {
            $i->{connection} = 1;
        } else {
            $font{$font} eq 'Helvetica' or die dump [$i, $text, $font];
        }
        
    } else {
        $i->{font} = $font;
    }
}

sub count_mile_headings {
    my ($lines, $station_col) = @_;
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or die;
    for (2..@$lines-1) {
        if ($_ % 2) {
            $lines->[$_] =~ m{^-[\d.]+ TJm\n$} or die $_;
        } else {
            $lines->[$_] =~ m{^\(Miles\) [\d.]+ Tj\n$} or die $_;
        }
    }
    my $count = (@$lines - 1) / 2;
    $count == $station_col or dump $lines;
    $count == $station_col or die "$count != $station_col";
    return $count;
}

sub parse_mile_col {
    my ($lines, $mile_cols) = @_;
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or die;
}

sub parse_table_text {
    my $table = shift;
    my $count;
    my $row = 0;
    my $prev_y;
    my $prev_col;
    my $station_col_right = $table->{col_lines}[$table->{station_col}];
    my $station_col_left = $table->{station_col}
        ? $table->{col_lines}[$table->{station_col}-1]
        : $table->{x1} - 0.01;
    my @cur_station;
    my $seen_station_this_row;
    my $station_row;
    my @cur_time;
    my $mile_row;
#    print dump ($table->{text}), "\n";
    foreach (@{$table->{text}}) {
        $_->{col} = find_col($table, $_->{x});
        if (defined $prev_y and $_->{y} != $prev_y) {
            if ($_->{col} > $table->{station_col} and $_->{lines}[2] =~ m{^\(A\) [\d.]+ Tj\n$}) {
                next; # check column heading note
            }
            if (defined ($mile_row) and not $_->{col} < $table->{station_col}) {
                if ($_->{lines}[2] =~ m{^\(and\) [\d.]+ Tj\n$}) {
                    print "$_->{col} and at the same minutes past each hour until\n";
                } else {
                    $_->{lines}[2] =~ m{^\(A\) [\d.]+ Tj\n$} or die dump $_;
                }
                next;
            }
            $count = 0;
            $row++;
            $seen_station_this_row = 0;
        }
        $_->{row} = $row;
#        print find_row($table, $_->{y}), " ", dump ($_), "\n";
        if ($_->{x} > $station_col_right) {
            if ($row == 0) {
                $table->{train_col_headings} = parse_train_col_headings($_, $table);
            } elsif (not $seen_station_this_row) {
#                if ($table->{stations}) {
#                    print "no station: ", dump($_), "\n";
#                } else {
#                    print "train flags: ", dump($_), "\n";
#                }
            }
        }
        if ($_->{col} < $table->{station_col}) {
            if (not defined $mile_row) {
                $table->{mile_cols} = count_mile_headings($_->{lines}, $table->{station_col});
                $mile_row = $_->{row};
            } else {
                $mile_row++;
#                print dump ($_), "\n";
                $mile_row == $_->{row} or die "mile row mismatch: $mile_row != $_->{row}";
                parse_mile_col($_->{lines}, $table->{mile_cols});
            }
        }
        if ($_->{col} == $table->{station_col}) {
            $row > 0 or die "$row, $_->{col}, $table->{station_col}\n", dump $_;
            $seen_station_this_row = 1;
            push @cur_station, $_;
            if (defined $station_row) {
                $row == $station_row or die;
            } else {
                $station_row = $row;
            }
        } elsif (@cur_station) {
            my $y = $cur_station[0]{y};
            my @found = grep { $_->{y} > ($y-1) and $_->{y} < ($y+1) }
                @{$table->{interchange_boxes}};
            @found < 2 or die;
            push @{$table->{stations}}, parse_station(\@cur_station, $station_col_left, $station_row, $found[0] || undef);
            @cur_station = ();
            undef $station_row;
        }

        if ($seen_station_this_row and $_->{col} > $table->{station_col}) {
            $_->{lines}[0] eq "0 0 Td\n" or die;
            $_->{lines}[1] =~ m{^/F\d+_0 1 Tf\n$} or die;
            $table->{train_times}[$row] ||= [];
            push @{$table->{train_times}[$row]}, $_;
#            print dump ($_), "\n";
#            if (@{$_->{lines}} > 5) {
#                print scalar @{$_->{lines}}, "\n";
#            }
        }

        $count++;
        $prev_y = $_->{y};
        $prev_col = $_->{col};
    }
    my $prev_station;
    foreach (@{$table->{stations}}) {
        if (not $_->{name}) {
            $prev_station or die;
            $_->{name} = $prev_station;
            undef $prev_station;
        } else {
            $prev_station = $_->{name};
        }
    }
}

sub parse_station {
    my ($text, $left, $row, $interchange_box) = @_;
    my %station = ( row => $row );
    foreach (@$text) {
        my $x = $_->{x} - $left;
#        $x < 0 and die;
        if (not $station{name}) {
            if ($x < 20) {
                %station = (%station, station_name($_->{lines}));
                $station{indent} = sprintf "%.1f", $x + 0.03;
                next;
            }
        } 
        if ($station{name}) {
            if (not defined $station{other_timetable}
                    and $interchange_box
                    and not defined $station{interchange_mins}) {
                %station = (%station, interchange_mins($_->{lines}));
                next if $station{interchange_mins};
            }
            if (not defined $station{interchange_note}
                    and interchange_note($_->{lines})) {
                $station{interchange_note} = 1;
                next;
            }
            if (not defined $station{underground}
                    and station_flag_underground($_->{lines})) {
                $station{underground} = 1;
                next;
            }
            if (not defined $station{metro}
                    and station_flag_metro($_->{lines})) {
                $station{metro} = 1;
                next;
            }
            if (not defined $station{bus}
                    and station_flag_bus($_->{lines})) {
                $station{bus} = 1;
                next;
            }
        }
        if (not defined $station{other_timetable}) {
            %station = (%station, other_timetable($_->{lines}));
            next if $station{other_timetable};
        }
        my $d_or_a = station_d_or_a($_->{lines});
        if ($d_or_a) {
            if ($station{d_or_a}) {
                $station{d_or_a} eq 'd' or die;
                $station{airport} = 1;
            }
            $station{d_or_a} = $d_or_a;
            next;
        }
        if ($station{name} and not $station{d_or_a}) {
            station_dots($_->{lines}) and next;
        }
        die dump { station => \%station, text => $_ };
        #die dump $text;
    }
    if ($station{name} and not $station{d_or_a} and $station{name} =~ /^(.*) ([ad])$/) {
        $station{name} = $1;
        $station{d_or_a} = $2;
    }
    return \%station;
}

sub parse_train_col_headings {
    my ($text, $table) = @_;
    my @lines = @{$text->{lines}};
    $lines[0] eq "0 0 Td\n" or die;
    $lines[@lines-1] eq "0 0 Td\n" and pop @lines;
    my $expect = "toc_font";
    my $x = $text->{x};
    my @headings;
    foreach (@lines[1..@lines-1]) {
        my $col = find_col($table, $x);
        if ($expect eq "toc_font") {
            $_ =~ m{^/F\d+_0 1 Tf$} or die "bad font", dump \@lines;
            $expect = "toc";
            next;
        }
        if ($expect eq "toc") {
            if (/^(-?[\d.]+) -[\d.]+ Td\n$/) {
                $x=$text->{x} + $1*$text->{mul_x}; 
                $expect = "flag_font";
                next;
            }
            if (/^\(([A-Z]{2})\) ([\d.]+) Tj\n$/) {
                $headings[$col] = { toc => $1 };
                $x += $2 * $text->{mul_x};
            } elsif (/^(-[\d.]+) TJm$/) {
                $x += -$1 * 0.001 * $text->{mul_x};
            } else {
                die "unknown command: $_";
            }
            next;
        }
        if ($expect eq "flag_font") {
            m{^/F\d+_0 1 Tf\n$} or die "bad flag_font: $_";
            $expect = "flag";
            next;
        }
        if ($expect eq "flag") {
            /^\(([A-Za-z]{2,3})\) ([\d.]+) Tj\n$/ or die "bad Tj: $_";
            $headings[$col]{flag} = $1;
            $x += $2 * $text->{mul_x};
            $expect = "td";
            next;
        }
        if ($expect eq "td") {
            /^([\d.]+) 0 Td\n$/ or die "bad td: $_";
            $x=$text->{x} + $1*$text->{mul_x}; 
            $expect = "toc_font";
            next;
        }
    }
    return \@headings;
}

sub find_col {
    my ($table, $x) = @_;
    my $col = 0;
    foreach my $col_line (@{$table->{col_lines}}) {
        $x < $col_line and last;
        $col++;
    }
    return $col;
}

sub find_row {
    my ($table, $y) = @_;
    my $row = 0;
    foreach my $row_line (@{$table->{row_lines}}) {
        $y < $row_line and last;
        $row++;
    }
    return @{$table->{row_lines}} - $row;
}


sub find_station_col {
    my $table = shift;
    my $left = $table->{x1};
    my $col = firstidx {
        my $w = $_ - $left; $left = $_; $w > 45
    } @{$table->{col_lines}};
    $col == -1 and die;
    return $col;
}

sub find_col_widths {
    my $table = shift;
    my $left = $table->{x1};
    print dump [map {
        my $w = $_ - $left; $left = $_; $w;
    } @{$table->{col_lines}}];
}

sub in_table {
    my ($table, $point) = @_;
    $point->{y} > $table->{y2} and $point->{y} < $table->{y1};
}

sub in_table2 {
    my ($table, $point) = @_;
    $point->{y} > $table->{y2} and $point->{y} < $table->{y1}
        and $point->{x} > $table->{x1} - 0.01 and $point->{x} < $table->{x2};
}

sub find_row_lines {
    map $_->{y}, sort { $b->{y} <=> $a->{y} } 
        grep { $_->{w} > 20 and $_->{h} < 0.2 } @_
}

sub find_col_lines {
    my $t = shift;
    my $prev = 0;
    my (%line_x, %line_y);
#    print dump ([grep { $_->{w} < 0.9 and $_->{h} > 1 } @_]), "\n";
    foreach (grep { $_->{w} < 0.9 and $_->{h} > 1 } @{$t->{table_lines}}) {
        $line_x{$_->{x}} ||= 0;
        $line_x{$_->{x}}++;
        $line_y{$_->{y}} ||= 0;
        $line_y{$_->{y}}++;
    }
    my $size;
    foreach (values %line_x) {
        if (defined $size) {
            #$size == $_ or die dump \%line;
            $size == $_ and next;
            return;
            die "merged columns\n";
        } else {
            $size = $_;
        }
    }
    my $size_y;
    foreach (values %line_y) {
        if (defined $size_y) {
            #$size == $_ or die dump \%line;
            $size_y == $_ and next;
            die "$_\n", dump \%line_y;
        } else {
            $size_y = $_;
        }
    }
    $t->{col_lines} = [sort { $a <=> $b } keys %line_x];
    $t->{row_lines} = [sort { $a <=> $b } keys %line_y];
#    print dump (\%line), "\n";
#    map { $prev eq $_->{x} ? () : ($prev = $_->{x}) }
#        sort { $a->{x} <=> $b->{x} } 
#        grep { $_->{w} < 0.9 and $_->{h} > 1 } @_
}

sub find_interchange_min_box {
    grep { $_->{w} > 3 and $_->{w} < 10 and $_->{h} > 4.5 and $_->{h} < 5 } @_;
}

sub find_tables {
    my $self = shift;
    my @h = sort { $b->{y} <=> $a->{y} } 
        grep { $_->{w} > 20 and $_->{h} > 0.2 and $_->{h} < 0.8 } @{$self->lines};
    @h % 2 and die "bad number of lines: ", scalar @h;
    $self->tables([map {
        my ($t, $b) = ($h[$_ * 2], $h[$_ * 2 + 1]);
        {   x1  => $t->{x},             y1  => $t->{y},
            x2  => $t->{x} + $t->{w},   y2  => $b->{y},
            h   => $t->{y} - $b->{y},   w   => $t->{w},};
    } 0..(@h/2)-1]);
}

#sub parse_text {
#    my $self = shift;
#
#    my $prev_col;
#    foreach (@{$self->text}) {
#        my $table_num = which_table($page, { x => $_->{x}, y => $_->{y} });
#        defined $table_num or next;
#        my $i = 0;
#        my $col;
#        my $table = $page->{tables}[$table_num];
#        foreach my $col_line (@{$table->{col_lines}}) {
#            $_->{x} < $col_line and do { $col = $i; last; };
#            $i++;
#        }
#        defined $col or $col = $i;
#        my $row = 0;
#        if ($col == $table->{station_col}
#                and (not defined $prev_col or $col != $prev_col)) {
#            push @{$table->{stations}}, station_name($_->{lines});
#        }
#        $prev_col = $col;
#    }
#}

sub station_name {
    my $lines = shift;
    my @lines = @$lines;
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F(\d+)_0 1 Tf\n$} or die;
    my @name;
    my $d_or_a = 0;
    my $i;
    foreach my $num (2..@lines-1) {
        $_ = $lines->[$num];
        $_ eq "0 0 Td\n" and last;
        if (/^[\d.]+ 0 Td\n$/) {
            $i = $num;
            last;
        }
        s/\\330/fl/g;
        s/\\306/fi/g;
        /.* TJm$/ and next;
        /^\((.*)\) [\d\.]+ Tj/ or die "bad tj: ", dump $lines;
        push @name, $1;
    }
    my %station = (name => join " ", @name);
    if ($i) {
        $i++;
        $lines[$i++] =~ m!/F\d+_0 1 Tf\n! or die;
        my @other;
        while ($lines[$i++] =~ m{^\((\d+),\) [\d.]+ Tj\n$}) {
            push @other, $1;
            $lines[$i++] =~ /^-[\d.]+ TJm\n$/ or print "broken!";
        }
        $i--;
        if ($lines[$i++] =~ m{^\((\d+)\) [\d.]+ Tj\n$}) {
            push @other, $1;
            $station{other_timetable} = \@other;
            $lines[$i++] =~ /.* TJm$/ or die;
            $i++;
        }
        $i--;
        $lines[$i] =~ m{^\(([da])\) [\d.]+ Tj\n$} or die dump $lines;
        $station{d_or_a} = $1;
    }
    return %station;
}

sub interchange_mins {
    my $lines = shift;
    $lines->[0] eq "0 0 Td\n" or die "bad td: $_";
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or return ();
    $lines->[2] =~ m{^\((\d+)\) [\d.]+ Tj\n$} or return ();
    my $mins = $1;
    my %station = (interchange_mins => $mins);
    if (@$lines == 4) {
        $lines->[3] eq "0 0 Td\n" or die;
        return %station;
    } elsif (@$lines == 5) {
        $lines->[3] =~ /^-[\d.]+ TJm\n$/ or die $lines->[3];
        $lines->[4] =~ m{^\(([ad])\) [\d.]+ Tj\n$} or die;
        $station{d_or_a} = $1;
        return %station;
    } else {
        die "bad interchange", dump($lines), "\n";
    }
}

sub interchange_note {
    my $lines = shift;
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or return;
    $lines->[2] =~ m{^\(\\(337|001)\) [\d.]+ Tj\n$} or return;
    @$lines == 3 or die;
    return 1;
}

sub station_flag_underground {
    my $lines = shift;
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or return;
    $lines->[2] =~ m{^\(j\) [\d.]+ Tj\n$} or return;
    @$lines == 3 or die;
    return 1;
}

sub station_flag_bus {
    my $lines = shift;
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or return;
    $lines->[2] =~ m{^\(D\) [\d.]+ Tj\n$} or return;
    @$lines == 3 or die;
    return 1;
}

sub station_flag_metro {
    my $lines = shift;
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or return;
    $lines->[2] =~ m{^\(b\) [\d.]+ Tj\n$} or return;
    @$lines == 3 or die;
    return 1;
}

sub other_timetable {
    my $lines = shift;
    my @other;
    $lines->[0] eq "0 0 Td\n" or die dump $lines;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or return ();
    my $i = 2;
    while ($lines->[$i] =~ m{^\((\d+),\) [\d.]+ Tj\n$}) {
        push @other, $1;
        $lines->[++$i] =~ /^-[\d.]+ TJm\n$/ or die;
        $i++;
    }
    $lines->[$i] =~ m{^\((\d+)\) [\d.]+ Tj\n$} or return ();
    push @other, $1;
    my %station = (other_timetable => \@other);
    if (@$lines == $i+1) {
        return %station;
    } elsif (@$lines == $i+3) {
        $lines->[@$lines-2] =~ /^-[\d.]+ TJm\n$/ or die dump $lines;
        $lines->[@$lines-1] =~ m{^\(([ad])\) [\d.]+ Tj\n$} or die;
        $station{d_or_a} = $1;
        return %station;
    }
    die dump $lines;
}

sub station_d_or_a {
    my $lines = shift;
    $lines->[0] eq "0 0 Td\n" or die;
    $lines->[1] =~ m{^/F\d+_0 1 Tf\n$} or return;
    $lines->[2] =~ m{^\(([ad])\) [\d.]+ Tj\n$} or return;
    @$lines == 3 or die;
    return $1;
}

sub station_dots {
    my $lines = shift;
    @$lines == 3 or return;
    $lines->[0] eq "0 0 Td\n" or return;
    $lines->[1] =~ m{^/F\d+_0 1 Tf$} or return;
    $lines->[2] =~ m{^\(\.+\) [\d.]+ Tj\n$} or return;
    return 1;
}

1;

package main;

my $filename = "CompleteTimetable.ps";

my $convert_pdf = 'pdftops -noembt1 -noembtt -noembcidps -noembcidtt -nocrop -noshrink -nocenter CompleteTimetable.pdf';
-e $filename or system $convert_pdf;

Page->load($filename);
