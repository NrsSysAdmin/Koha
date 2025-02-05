[% USE Branches %]
[% IF ( CAN_user_catalogue ) %]
    <div id="catalog_search" class="residentsearch">
        <form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
            <label class="tip" for="search-form">Enter search keywords:</label>
            [% IF ( Koha.Preference('IntranetCatalogSearchPulldown') ) %]
                [% INCLUDE 'search_indexes.inc' $header_pulldown = 1 %]
            [% END %]
            [% IF ( Koha.Preference('RetainCatalogSearchTerms') ) %]
                <input type="text" name="q" id="search-form" size="40" value="[% ms_value | html %]" title="Enter the terms you wish to search for." class="query form-text head-searchbox" />
            [% ELSE %]
                <input type="text" name="q" id="search-form" size="40" title="Enter the terms you wish to search for." class="query form-text head-searchbox" />
            [% END %]
            [% IF ( Koha.Preference('IntranetAddMastheadLibraryPulldown') ) %]
                <select id="select_library" name="limit" style="margin-left:5px;">
                    <option value="">All libraries</option>
                    [% PROCESS options_for_libraries prefix => "branch:" libraries => Branches.all( selected => branch_limit ) %]
                </select>
            [% END %]
            <input type="submit" value="Submit"  class="submit" />
        </form>
    </div>
[% END %]
