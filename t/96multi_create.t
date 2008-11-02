use strict;
use warnings;

use Test::More;
use lib qw(t/lib);
use DBICTest;

plan tests => 51;

my $schema = DBICTest->init_schema();

# simple create + belongs_to
eval {
  my $cd2 = $schema->resultset('CD')->create({
    artist => { 
      name => 'Fred Bloggs' 
    },
    title => 'Some CD',
    year => 1996
  });

  isa_ok($cd2, 'DBICTest::CD', 'Created CD object');
  isa_ok($cd2->artist, 'DBICTest::Artist', 'Created related Artist');
  is($cd2->artist->name, 'Fred Bloggs', 'Artist created correctly');
};
diag $@ if $@;

# create over > 1 levels of has_many create (A => { has_many => { B => has_many => C } } )
eval {
  my $artist = $schema->resultset('Artist')->create(
    { name => 'Fred 2',
      cds => [
        { title => 'Music to code by',
          year => 2007,
          tags => [
            { 'tag' => 'rock' },
          ],
        },
    ],
  });

  isa_ok($artist, 'DBICTest::Artist', 'Created Artist');
  is($artist->name, 'Fred 2', 'Artist created correctly');
  is($artist->cds->count, 1, 'One CD created for artist');
  is($artist->cds->first->title, 'Music to code by', 'CD created correctly');
  is($artist->cds->first->tags->count, 1, 'One tag created for CD');
  is($artist->cds->first->tags->first->tag, 'rock', 'Tag created correctly');

  # Create via update - add a new CD
  $artist->update({
    cds => [ $artist->cds,
      { title => 'Yet another CD',
        year => 2006,
      },
    ],
  });
  is(($artist->cds->search({}, { order_by => 'year' }))[0]->title, 'Yet another CD', 'Updated and added another CD');

  my $newartist = $schema->resultset('Artist')->find_or_create({ name => 'Fred 2'});

  is($newartist->name, 'Fred 2', 'Retrieved the artist');
};
diag $@ if $@;

# nested find_or_create
eval {
  my $newartist2 = $schema->resultset('Artist')->find_or_create({ 
    name => 'Fred 3',
    cds => [
      { 
        title => 'Noah Act',
        year => 2007,
      },
    ],
  });
  is($newartist2->name, 'Fred 3', 'Created new artist with cds via find_or_create');
};
diag $@ if $@;

# multiple same level has_many create
eval {
  my $artist2 = $schema->resultset('Artist')->create({
    name => 'Fred 3',
    cds => [
      {
        title => 'Music to code by',
        year => 2007,
      },
    ],
    cds_unordered => [
      {
        title => 'Music to code by',
        year => 2007,
      },
    ]
  });

  is($artist2->in_storage, 1, 'artist with duplicate rels inserted okay');
};
diag $@ if $@;

# first create_related pass
eval {
	my $artist = $schema->resultset('Artist')->first;
	
	my $cd_result = $artist->create_related('cds', {
	
		title => 'TestOneCD1',
		year => 2007,
		tracks => [
		
			{ position=>111,
			  title => 'TrackOne',
			},
			{ position=>112,
			  title => 'TrackTwo',
			}
		],

	});
	
	ok( $cd_result && ref $cd_result eq 'DBICTest::CD', "Got Good CD Class");
	ok( $cd_result->title eq "TestOneCD1", "Got Expected Title");
	
	my $tracks = $cd_result->tracks;
	
	ok( ref $tracks eq "DBIx::Class::ResultSet", "Got Expected Tracks ResultSet");
	
	foreach my $track ($tracks->all)
	{
		ok( $track && ref $track eq 'DBICTest::Track', 'Got Expected Track Class');
	}
};
diag $@ if $@;

# second create_related with same arguments
eval {
	my $artist = $schema->resultset('Artist')->first;
	
	my $cd_result = $artist->create_related('cds', {
	
		title => 'TestOneCD2',
		year => 2007,
		tracks => [
		
			{ position=>111,
			  title => 'TrackOne',
			},
			{ position=>112,
			  title => 'TrackTwo',
			}
		],

    liner_notes => { notes => 'I can haz liner notes?' },

	});
	
	ok( $cd_result && ref $cd_result eq 'DBICTest::CD', "Got Good CD Class");
	ok( $cd_result->title eq "TestOneCD2", "Got Expected Title");
  ok( $cd_result->notes eq 'I can haz liner notes?', 'Liner notes');
	
	my $tracks = $cd_result->tracks;
	
	ok( ref $tracks eq "DBIx::Class::ResultSet", "Got Expected Tracks ResultSet");
	
	foreach my $track ($tracks->all)
	{
		ok( $track && ref $track eq 'DBICTest::Track', 'Got Expected Track Class');
	}
};
diag $@ if $@;

# create of parents of a record linker table
eval {
  my $cdp = $schema->resultset('CD_to_Producer')->create({
    cd => { artist => 1, title => 'foo', year => 2000 },
    producer => { name => 'jorge' }
  });
  ok($cdp, 'join table record created ok');
};
diag $@ if $@;

#SPECIAL_CASE
eval {
  my $kurt_cobain = { name => 'Kurt Cobain' };

  my $in_utero = $schema->resultset('CD')->new({
      title => 'In Utero',
      year  => 1993
    });

  $kurt_cobain->{cds} = [ $in_utero ];


  $schema->resultset('Artist')->populate([ $kurt_cobain ]); # %)
  $a = $schema->resultset('Artist')->find({name => 'Kurt Cobain'});

  is($a->name, 'Kurt Cobain', 'Artist insertion ok');
  is($a->cds && $a->cds->first && $a->cds->first->title, 
		  'In Utero', 'CD insertion ok');
};
diag $@ if $@;

#SPECIAL_CASE2
eval {
  my $pink_floyd = { name => 'Pink Floyd' };

  my $the_wall = { title => 'The Wall', year  => 1979 };

  $pink_floyd->{cds} = [ $the_wall ];


  $schema->resultset('Artist')->populate([ $pink_floyd ]); # %)
  $a = $schema->resultset('Artist')->find({name => 'Pink Floyd'});

  is($a->name, 'Pink Floyd', 'Artist insertion ok');
  is($a->cds && $a->cds->first->title, 'The Wall', 'CD insertion ok');
};
diag $@ if $@;

## Create foreign key col obj including PK
## See test 20 in 66relationships.t
eval {
  my $new_cd_hashref = { 
    cdid => 27, 
    title => 'Boogie Woogie', 
    year => '2007', 
    artist => { artistid => 17, name => 'king luke' }
  };

  my $cd = $schema->resultset("CD")->find(1);

  is($cd->artist->id, 1, 'rel okay');

  my $new_cd = $schema->resultset("CD")->create($new_cd_hashref);
  is($new_cd->artist->id, 17, 'new id retained okay');
};
diag $@ if $@;

eval {
	$schema->resultset("CD")->create({ 
              cdid => 28, 
              title => 'Boogie Wiggle', 
              year => '2007', 
              artist => { artistid => 18, name => 'larry' }
             });
};
is($@, '', 'new cd created without clash on related artist');

# Make sure exceptions from errors in created rels propogate
eval {
    my $t = $schema->resultset("Track")->new({ cd => { artist => undef } });
    #$t->cd($t->new_related('cd', { artist => undef } ) );
    #$t->{_rel_in_storage} = 0;
    $t->insert;
};
like($@, qr/cd.artist may not be NULL/, "Exception propogated properly");

# Test multi create over many_to_many
eval {
  $schema->resultset('CD')->create ({
    artist => {
      name => 'larry', # should already exist
    },
    title => 'Warble Marble',
    year => '2009',
    cd_to_producer => [
      { producer => { name => 'Cowboy Neal' } },
    ],
  });

  my $m2m_cd = $schema->resultset('CD')->search ({ title => 'Warble Marble'});
  is ($m2m_cd->count, 1, 'One CD row created via M2M create');
  is ($m2m_cd->first->producers->count, 1, 'CD row created with one producer');
  is ($m2m_cd->first->producers->first->name, 'Cowboy Neal', 'Correct producer row created');
};

# and some insane multicreate 
# (should work, despite the fact that no one will probably use it this way)

# first count how many rows do we initially have

my $counts;
$counts->{$_} = $schema->resultset($_)->count for qw/Artist CD Genre Producer Tag/;

# do the crazy create
eval {
  $schema->resultset('CD')->create ({
    artist => {
      name => 'larry',
    },
    title => 'Greatest hits 1',
    year => '2012',
    genre => {
      name => '"Greatest" collections',
    },
    tags => [
      { tag => 'A' },
      { tag => 'B' },
    ],
    cd_to_producer => [
      {
        producer => {
          name => 'Dirty Harry',
          producer_to_cd => [
            {
              cd => { 
                artist => {
                  name => 'Dirty Harry himself',
                  cds => [
                    {
                      title => 'Greatest hits 3',
                      year => 2012,
                      genre => {
                        name => '"Greatest" collections',
                      },
                      tags => [
                        { tag => 'A' },
                        { tag => 'B' },
                      ],
                    },
                  ],
                },
                title => 'Greatest hits 2',
                year => 2012,
                genre => {
                  name => '"Greatest" collections',
                },
                tags => [
                  { tag => 'A' },
                  { tag => 'B' },
                ],
              },
            },
            {
              cd => { 
                artist => {
                  name => 'larry',    # should already exist
                },
                title => 'Greatest hits 4',
                year => 2012,
              },
            },
          ],
        },
      },
    ],
  });

  is ($schema->resultset ('Artist')->count, $counts->{Artist} + 1, 'One new artists created');  # even though the 'name' is not uniquely constrained find_or_create will arguably DWIM
  is ($schema->resultset ('Genre')->count, $counts->{Genre} + 1, 'One additional genre created');
  is ($schema->resultset ('Producer')->count, $counts->{Producer} + 1, 'One new producer');
  is ($schema->resultset ('CD')->count, $counts->{CD} + 4, '4 new CDs');
  is ($schema->resultset ('Tag')->count, $counts->{Tag} + 6, '6 new Tags');

  my $harry_cds = $schema->resultset ('Artist')->single ({name => 'Dirty Harry himself'})->cds;
  is ($harry_cds->count, 2, 'Two CDs created by Harry');
  ok ($harry_cds->single ({title => 'Greatest hits 2'}), 'First CD name correct');
  ok ($harry_cds->single ({title => 'Greatest hits 3'}), 'Second CD name correct');

  my $harry_productions = $schema->resultset ('Producer')->single ({name => 'Dirty Harry'})
    ->search_related ('producer_to_cd', {})->search_related ('cd', {});
  is ($harry_productions->count, 4, 'All 4 CDs are produced by Harry');
  is ($harry_productions->search ({ year => 2012 })->count, 4, 'All 4 CDs have the correct year');

  my $hits_genre = $schema->resultset ('Genre')->single ({name => '"Greatest" collections'});
  ok ($hits_genre, 'New genre row found');
  is ($hits_genre->cds->count, 3, 'Three of the new CDs fall into the new genre');

  my $a_tags = $schema->resultset('Tag')->search({ tag => 'A'});
  my $b_tags = $schema->resultset('Tag')->search({ tag => 'A'});
  is ($a_tags->count, 3, '3 A tags');
  is ($a_tags->count, 3, '3 B tags');

  my $cds_with_ab = $schema->resultset('CD')
    ->search({ 'tags.tag' => { -in => [qw/A B/] } }, { join => 'tags', group_by => 'me.cdid' } );
  is ($cds_with_ab->count, 3, '6 tags were pairwise distributed between 3 CDs');
};
diag $@ if $@;
