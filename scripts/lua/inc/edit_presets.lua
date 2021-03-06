--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"

local host_pools_utils = require "host_pools_utils"
local template = require "template_utils"
local presets_utils = require "presets_utils"
local discover = require "discover_utils"

-- Administrator check
if not isAdministrator() then
   return
end

local page = _GET["page"] or ""
local policy_filter = _GET["policy_filter"] or ""
local proto_filter = _GET["l7proto"] or ""
local device_type = _GET["device_type"] or "0" -- unknown by default

local base_url = ""
if ntop.isnEdge() then
   base_url = "/lua/pro/nedge/admin/nf_edit_user.lua"
else
   base_url = "/lua/admin/edit_device_protocols.lua"
end

-- ###################################################################

local page_params = {}

page_params["page"] = page

if not isEmptyString(policy_filter) then
  page_params["policy_filter"] = policy_filter
end

if not isEmptyString(proto_filter) then
  page_params["l7proto"] = proto_filter
end

if not isEmptyString(device_type) then
  page_params["device_type"] = device_type
end

-- ###################################################################

function editDeviceProtocols()
   local reload = false

   for k,v in pairs(_POST) do
      if starts(k, "client_policy_") then
         local proto = split(k, "client_policy_")[2]
         local action_id = v
         presets_utils.updateDeviceProto(device_type, "client", proto, action_id)
         reload = true
      end
      if starts(k, "server_policy_") then
         local proto = split(k, "server_policy_")[2]
         local action_id = v
         presets_utils.updateDeviceProto(device_type, "server", proto, action_id)
         reload = true
      end
   end

   if reload then
      presets_utils.reloadDevicePolicies(device_type)
   end
end

-- ###################################################################

local function printDevicePolicyLegenda() 
   print[[<div style='float:left;'><ul style='display:inline; padding:0'>]]

   for _, action in ipairs(presets_utils.actions) do
      print("<li style='display:inline-block; margin-right: 14px;'>".. string.gsub(action.icon, "\"", "'") .. " " .. action.text .. "</li>")
   end

   print[[</ul></div>]]
end

-- ###################################################################

local function printDeviceProtocolsPage()
   local form_id = "device-protocols-form"
   local table_id = "device-protocols-table"

   print[[ <h2 style="margin-top: 0; margin-bottom: 20px;">]]
   if ntop.isnEdge() then
      local pool_name = host_pools_utils.DEFAULT_POOL_NAME
      print(i18n("nedge.user_device_protocols", {user=pool_name})) 
   else
      print(i18n("device_protocols.device_protocols")) 
   end
   print[[</h2>

   <table style="width:100%; margin-bottom: 20px;"><tbody>
     <tr>
       <td style="white-space:nowrap; padding-right:1em;">]]

   -- Device type selector
   print(i18n("details.device_type")) print(': <select id="device_type_selector" class="form-control device-type-selector" style="display:inline; width: 200px" onchange="document.location.href=\'?page=device_protocols&l7proto=') print(proto_filter) print('&device_type=\' + $(this).val()">')
   discover.printDeviceTypeSelectorOptions(device_type, false)
   print[[</select></td><td style="width:100%"></td>]]

   -- Active protocol filter
   if not isEmptyString(proto_filter) then
      local proto_name = interface.getnDPIProtoName(tonumber(proto_filter))

      local proto_filter_params = table.clone(page_params)
      proto_filter_params.device_type = device_type
      proto_filter_params.l7proto = nil

      print[[<td style="padding-top: 15px;">
      <form action="]] print(base_url) print[[">]]
      for k,v in pairs(proto_filter_params) do
         print[[<input type="hidden" name="]] print(k) print[[" value="]] print(v) print[[" />]]
      end
      print[[
        <button type="button" class="btn btn-default btn-sm" style="margin-bottom: 18px;" onclick="$(this).closest('form').submit();">
          <i class="fa fa-close fa-lg" aria-hidden="true" data-original-title="" title=""></i> ]] print(proto_name) print[[
        </button>
      </form>
    </td>]]
   end

   print[[<td>]]

   -- Remove policy filter on search
   local after_search_params = table.clone(page_params)
   after_search_params.device_type = device_type
   after_search_params.l7proto = nil
   after_search_params.policy_filter = nil

   -- Protocol search form
   print(
      template.gen("typeahead_input.html", {
         typeahead={
            base_id     = "t_app",
            action      = base_url,
            parameters  = after_search_params,
            json_key    = "key",
            query_field = "l7proto",
            query_url   = ntop.getHttpPrefix() .. "/lua/find_app.lua?skip_critical=true",
            query_title = i18n("nedge.search_protocols"),
            style       = "margin-left:1em; width:25em;",
         }
      })
   )

   print[[</td></tr></tbody></table>]]

   -- Table form
   print[[<form id="]] print(form_id) print[[" lass="form-inline" style="margin-bottom: 0px;" method="post">
      <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[">
      <div id="]] print(table_id) print[["></div>
      <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
   </form>
   <span>
   ]] print(i18n("notes")) print[[
   <ul>
     <li>]] 
   print(i18n("nedge.device_protocol_policy_has_higher_priority")) print[[
     </li>
   </ul>
   </span>

   <script type="text/javascript">
    aysHandleForm("#]] print(form_id) print[[");
    $("#]] print(form_id) print[[").submit(function() {
      var form = $("#]] print(form_id) print[[");

      // Serialize form data
      var params = {};
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      params.edit_device_policy = "";

      datatableForEachRow($("#]] print(table_id) print[["), function() {
        var row = $(this);
        var proto_id = $("td:nth-child(1)", row).html();
        var client_action_id = $("td:nth-child(3)", row).find("input[type=radio]:checked").val();
        var server_action_id = $("td:nth-child(4)", row).find("input[type=radio]:checked").val();
        params["client_policy_" + proto_id] = client_action_id;
        params["server_policy_" + proto_id] = server_action_id;
      });

      aysResetForm("#]] print(form_id) print[[");
      paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
      return false;
    });

  var url_update = "]] print (ntop.getHttpPrefix())
   print[[/lua/admin/get_device_protocols.lua?device_type=]] print(device_type)
   if not isEmptyString(policy_filter) then print("&policy_filter=" .. policy_filter) end
   if not isEmptyString(proto_filter) then print("&l7proto=" .. proto_filter) end
   print[[";

  var legend_appended = false;

  $("#]] print(table_id) print[[").datatable({
    url: url_update ,
    class: "table table-striped table-bordered table-condensed",
]]

   -- Table preferences
   local preference = tablePreferences("rows_number_policies", _GET["perPage"])
   if isEmptyString(preference) then preference = "10" end
   print ('perPage: '..preference.. ",\n")

   print[[
         tableCallback: function(opts) {
          if (! legend_appended) {
            legend_appended = true;
            $("#]] print(table_id) print[[ .dt-toolbar-container").append("]]

  -- Legenda
  printDevicePolicyLegenda()

  print[[")};
           datatableForEachRow($("#]] print(table_id) print[["), function() {
              var row = $(this);
              var proto_id = $("td:nth-child(1)", row).html();
           });

           aysResetForm("#]] print(form_id) print[[");
         }, showPagination: true, title:"",
          buttons: []]
          print('\'<div class="btn-group pull-right"><div class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..
            i18n("nedge.filter_policies") .. ternary(not isEmptyString(policy_filter), '<span class="glyphicon glyphicon-filter"></span>', '') ..
            '<span class="caret"></span></div> <ul class="dropdown-menu" role="menu" style="min-width: 90px;">')

          -- 'Filter Policies' dropdown menu
          local entries = { {text=i18n("all"), id=""} }
          entries[#entries + 1] = ""
          for _, action in ipairs(presets_utils.actions) do
            entries[#entries + 1] = {text=action.text, id=action.id, icon=action.icon .. "&nbsp;&nbsp;"}
          end
          for _, entry in pairs(entries) do
            if entry ~= "" then
              page_params["policy_filter"] = entry.id
              -- page_params["device_type"] = device_type
              print('<li' .. ternary(policy_filter == entry.id, ' class="active"', '') .. '><a href="' .. getPageUrl(base_url, page_params) .. '">' .. (entry.icon or "") .. entry.text .. '</a></li>')
            else
              print('<li role="separator" class="divider"></li>')
            end
          end
          page_params["policy_filter"] = nil
          print('</ul></div>\'], ')

          -- datatable columns definition
          print[[columns: [
            {
              title: "",
              field: "column_ndpi_application_id",
              hidden: true,
              sortable: false,
            },{
              title: "]] print(i18n("application")) print[[",
              field: "column_ndpi_application",
              sortable: true,
                css: {
                  width: '65%',
                  textAlign: 'left',
                  verticalAlign: 'middle',
              }
            },
            {
              title: "]] print(i18n("users.client_policy")) print[[",
              field: "column_client_policy",
              sortable: false,
                css: {
                  width: '280',
                  textAlign: 'center',
                  verticalAlign: 'middle',
              }
            },
            {
              title: "]] print(i18n("users.server_policy")) print[[",
              field: "column_server_policy",
              sortable: false,
                css: {
                  width: '280',
                  textAlign: 'center',
                  verticalAlign: 'middle',
              }
            },
]
  });
       </script>
]]
end

-- ###################################################################

if _POST["edit_device_policy"] ~= nil then
  editDeviceProtocols()
end

printDeviceProtocolsPage()


