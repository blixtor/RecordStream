package Recs::Operation::frommultire;

use strict;

use base qw(Recs::Operation);

sub init {
   my $this = shift;
   my $args = shift;

   my %options = (
      "no-flush-regex|regex|re=s"   => sub { $this->add_regex($_[1], 0, 0); },
      "pre-flush-regex|pre=s"       => sub { $this->add_regex($_[1], 1, 0); },
      "post-flush-regex|post=s"     => sub { $this->add_regex($_[1], 0, 1); },
      "double-flush-regex|double=s" => sub { $this->add_regex($_[1], 1, 1); },
      "clobber"                     => sub { $this->_set_clobber(1); },
      "keep-all"                    => sub { $this->_set_keep_all(1); },
      "keep=s"                      => sub { $this->add_keep(split(/,/, $_[1])); },
   );

   $this->parse_options($args, \%options);
}

sub add_regex {
   my ($this, $string, $pre_flush, $post_flush) = @_;

   $this->{'REGEXES'} ||= [];

   my $fields = [];
   if($string =~ /^([^=]*)=(.*)$/) {
      $fields = [split(/,/, $1)];
      $string = $2;
   }

   push @{$this->{'REGEXES'}}, [$string, $fields, $pre_flush, $post_flush]
}

sub _get_regexes {
   my ($this) = @_;
   return $this->{'REGEXES'} || [];
}

sub _set_clobber {
   my ($this, $value) = @_;
   $this->{'CLOBBER'} = $value;
}

sub get_clobber {
   my ($this) = @_;
   return $this->{'CLOBBER'} || 0;
}

sub _set_keep_all {
   my ($this, $value) = @_;
   $this->{'KEEP_ALL'} = $value;
}

sub get_keep_all {
   my ($this) = @_;
   return $this->{'KEEP_ALL'} || 0;
}

sub add_keep {
   my $this = shift;
   $this->{'KEEP'} ||= {};
   for my $field (@_) {
      $this->{'KEEP'}->{$field} = 1;
   }
}

sub check_keep {
   my ($this, $field) = @_;

   $this->{'KEEP'} ||= {};
   return $this->get_keep_all() || exists($this->{'KEEP'}->{$field});
}

sub run_operation {
   my ($this) = @_;

   my $record = Recs::Record->new();

   local @ARGV = @{$this->_get_extra_args()};
   while(my $line = <>) {
      chomp $line;

      my $regex_index = 0;
      for my $regex (@{$this->_get_regexes()}) {
         my ($string, $fields, $pre_flush, $post_flush) = @$regex;

         if(my @groups = ($line =~ $string)) {
            if(!$this->get_clobber()) {
               for(my $index = 0; $index < @groups; ++$index) {
                  my $field_name = ($index < @$fields) ? $fields->[$index] : ($regex_index . "-" . $index);
                  if(defined ${$record->guess_key_from_spec($field_name)}) {
                     $pre_flush = 1;
                  }
               }
            }

            if($pre_flush) {
               $record = $this->flush_record($record);
            }

            for(my $index = 0; $index < @groups; ++$index) {
               my $field_name = ($index < @$fields) ? $fields->[$index] : ($regex_index . "-" . $index);
               ${$record->guess_key_from_spec($field_name)} = $groups[$index];
            }

            if($post_flush) {
               $record = $this->flush_record($record);
            }
         }
         ++$regex_index;
      }
   }
   if(!$this->get_clobber() && scalar($record->keys())) {
      $record = $this->flush_record($record);
   }
}

sub flush_record {
   my ($this, $record) = @_;
   my $record2 = Recs::Record->new();
   for my $field ($record->keys()) {
      if($this->check_keep($field)) {
         $record2->set($field, $record->get($field));
      }
   }
   $this->push_record($record);
   return $record2;
}

sub add_help_types {
   my $this = shift;
   $this->use_help_type('keyspecs');
}

sub usage {
   return <<USAGE;
Usage: recs-frommultire <args> [<files>]
   Match multiple regexes against each line of input (or lines of <files>).
   Various parameters control when the accumulated fields are flushed to output
   as a record and which, if any, fields are cleared when the record is
   flushed.

   By default regexes do not necessarily flush on either side, would-be field
   collisions cause a flush, EOF causes a flush if any fields are set, and all
   fields are cleared on a flush.

Arguments:
   --no-flush-regex|--regex|--re <regex>   Add a normal regex.
   --pre-flush-regex|--pre <regex>         Add a regex that flushes before
                                           interpretting fields when matched.
   --post-flush-regex|--post <regex>       Add a regex that flushes after
                                           interpretting fields when matched.
   --double-flush-regex|--double <regex>   Add a regex that flushes both before
                                           and after interprettying fields when
                                           matched.
   --clobber                               Do not flush records when a field
                                           from a match would clobber an
                                           already existing field and do not
                                           flush at EOF.
   --keep-all                              Do not clear any fields on a flush.
   --keep <fields>                         Do not clear this comma separated
                                           list of fields on a flush.

   <regex> - Syntax is: '<KEY1>,<KEY2>=REGEX'.  KEY field names are optional.
   The key names may be key specs, see '--help-keyspecs' for more.  Field
   names may not be keygroups

Examples:
   Typical use case one: parse several fields on separate lines
      recs-frommultire --re 'fname,lname=^Name: (.*) (.*)\$' --re 'addr=^Address: (.*)\$'
   Typical use case two: some fields apply to multiple records ("department" here)
      recs-frommultire --post 'fname,lname=^Name: (.*) (.*)\$' --re 'department=^Department: (.*)\$' --clobber --keep team
USAGE
}

1;
