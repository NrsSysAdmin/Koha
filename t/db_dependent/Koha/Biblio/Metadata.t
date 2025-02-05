#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 3;
use Test::Exception;

use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Biblio qw( AddBiblio );
use Koha::Database;

BEGIN {
    use_ok('Koha::Biblio::Metadatas');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'record() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $title = 'Oranges and Peaches';

    # Create a valid record
    my $record = MARC::Record->new();
    my $field  = MARC::Field->new( '245', '', '', 'a' => $title );
    $record->append_fields($field);
    my ($biblio_id) = C4::Biblio::AddBiblio( $record, '' );

    my $metadata = Koha::Biblios->find($biblio_id)->metadata;
    my $record2  = $metadata->record;

    is( ref $record2, 'MARC::Record', 'Method record() returned a MARC::Record object' );
    is( $record2->field('245')->subfield("a"),
        $title, 'Title in 245$a matches title from original record object' );

    my $bad_data = $builder->build_object(
        {   class => 'Koha::Biblio::Metadatas',
            value => { format => 'marcxml', schema => 'MARC21', metadata => 'this_is_not_marcxml' }
        }
    );

    throws_ok { $bad_data->record; }
    'Koha::Exceptions::Metadata::Invalid', 'Exception thrown on bad record';

    my $exception = $@;
    is( $exception->id,     $bad_data->id, 'id passed correctly to exception' );
    is( $exception->format, 'marcxml',     'format passed correctly to exception' );
    is( $exception->schema, 'MARC21',      'schema passed correctly to exception' );

    my $bad_format = $builder->build_object(
        {   class => 'Koha::Biblio::Metadatas',
            value => { format => 'mij', schema => 'MARC21', metadata => 'something' }
        }
    );

    throws_ok { $bad_format->record; }
    'Koha::Exceptions::Metadata', 'Exception thrown on unhandled format';

    is( "$@",
        'Koha::Biblio::Metadata->record called on unhandled format: mij',
        'Exception message built correctly'
    );

    $schema->storage->txn_rollback;
};

subtest '_embed_items' => sub {
    plan tests => 8;

    $schema->storage->txn_begin();

    my $builder = t::lib::TestBuilder->new;
    my $library1 = $builder->build({
        source => 'Branch',
    });
    my $library2 = $builder->build({
        source => 'Branch',
    });
    my $itemtype = $builder->build({
        source => 'Itemtype',
    });

    my $biblio = $builder->build_sample_biblio();
    my $item_infos = [
        { homebranch => $library1->{branchcode}, holdingbranch => $library1->{branchcode} },
        { homebranch => $library1->{branchcode}, holdingbranch => $library1->{branchcode} },
        { homebranch => $library1->{branchcode}, holdingbranch => $library1->{branchcode} },
        { homebranch => $library2->{branchcode}, holdingbranch => $library2->{branchcode} },
        { homebranch => $library2->{branchcode}, holdingbranch => $library2->{branchcode} },
        { homebranch => $library1->{branchcode}, holdingbranch => $library2->{branchcode} },
        { homebranch => $library1->{branchcode}, holdingbranch => $library2->{branchcode} },
        { homebranch => $library1->{branchcode}, holdingbranch => $library2->{branchcode} },
    ];
    my $number_of_items = scalar @$item_infos;
    my $number_of_items_with_homebranch_is_CPL =
      grep { $_->{homebranch} eq $library1->{branchcode} } @$item_infos;

    my @itemnumbers;
    for my $item_info (@$item_infos) {
        my $itemnumber = $builder->build_sample_item(
            {
                biblionumber  => $biblio->biblionumber,
                homebranch    => $item_info->{homebranch},
                holdingbranch => $item_info->{holdingbranch},
                itype         => $itemtype->{itemtype}
            }
        )->itemnumber;

        push @itemnumbers, $itemnumber;
    }

    # Emptied the OpacHiddenItems pref
    t::lib::Mocks::mock_preference( 'OpacHiddenItems', '' );

    throws_ok { Koha::Biblio::Metadata->record() }
    'Koha::Exceptions::Metadata',
'Koha::Biblio::Metadata->record must be called on an instantiated object or like a class method with a record passed in parameter';

    my ($itemfield) =
      C4::Biblio::GetMarcFromKohaField( 'items.itemnumber' );
    my $record = $biblio->metadata->record;
    Koha::Biblio::Metadata->record(
        {
            record       => $record,
            embed_items  => 1,
            biblionumber => $biblio->biblionumber
        }
    );
    my @items = $record->field($itemfield);
    is( scalar @items, $number_of_items, 'Should return all items' );

    my $marc_with_items = $biblio->metadata->record({ embed_items => 1 });
    is_deeply( $record, $marc_with_items, 'A direct call to GetMarcBiblio with items matches');

    $record = $biblio->metadata->record({ embed_items => 1, itemnumbers => [ $itemnumbers[1], $itemnumbers[3] ] });
    @items = $record->field($itemfield);
    is( scalar @items, 2, 'Should return all items present in the list' );

    $record = $biblio->metadata->record({ embed_items => 1, opac => 1 });
    @items = $record->field($itemfield);
    is( scalar @items, $number_of_items, 'Should return all items for opac' );

    my $opachiddenitems = "
        homebranch: ['$library1->{branchcode}']";
    t::lib::Mocks::mock_preference( 'OpacHiddenItems', $opachiddenitems );

    $record = $biblio->metadata->record({ embed_items => 1 });
    @items = $record->field($itemfield);
    is( scalar @items,
        $number_of_items,
        'Even with OpacHiddenItems set, all items should have been embedded' );

    $record = $biblio->metadata->record({ embed_items => 1, opac => 1 });
    @items = $record->field($itemfield);
    is(
        scalar @items,
        $number_of_items - $number_of_items_with_homebranch_is_CPL,
'For OPAC, the pref OpacHiddenItems should have been take into account. Only items with homebranch ne CPL should have been embedded'
    );

    $opachiddenitems = "
        homebranch: ['$library1->{branchcode}', '$library2->{branchcode}']";
    t::lib::Mocks::mock_preference( 'OpacHiddenItems', $opachiddenitems );
    $record = $biblio->metadata->record({ embed_items => 1, opac => 1 });
    @items = $record->field($itemfield);
    is(
        scalar @items,
        0,
'For OPAC, If all items are hidden, no item should have been embedded'
    );

    $schema->storage->txn_rollback;
};
