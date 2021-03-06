--[[
License of this file:
---------------------
Copyright (C) 2013 RealBadAngel, Maciej Kasatkin <mk@realbadangel.pl>
Copyright (C) 2016 LNJ <lnj.git@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

screwdriver = {}

local function nextrange(x, max)
	x = x + 1
	if x > max then
		x = 0
	end
	return x
end

screwdriver.ROTATE_FACE = 1
screwdriver.ROTATE_AXIS = 2
screwdriver.disallow = function(pos, node, user, mode, new_param2)
	return false
end
screwdriver.rotate_simple = function(pos, node, user, mode, new_param2)
	if mode ~= screwdriver.ROTATE_FACE then
		return false
	end
end
local USES = 200

-- Handles rotation
function screwdriver.screwdriver_handler(itemstack, user, pointed_thing, mode)
	if pointed_thing.type ~= "node" then
		return
	end

	local pos = pointed_thing.under

	if core.is_protected(pos, user:get_player_name()) then
		core.record_protection_violation(pos, user:get_player_name())
		return
	end

	local node = core.get_node(pos)
	local ndef = core.registered_nodes[node.name]
	-- verify node is facedir (expected to be rotatable)
	if not ndef or ndef.paramtype2 ~= "facedir" then
		return
	end
	-- Compute param2
	local rotationPart = node.param2 % 32 -- get first 4 bits
	local preservePart = node.param2 - rotationPart
	local axisdir = math.floor(rotationPart / 4)
	local rotation = rotationPart - axisdir * 4
	if mode == screwdriver.ROTATE_FACE then
		rotationPart = axisdir * 4 + nextrange(rotation, 3)
	elseif mode == screwdriver.ROTATE_AXIS then
		rotationPart = nextrange(axisdir, 5) * 4
	end

	local new_param2 = preservePart + rotationPart
	local should_rotate = true

	if ndef and ndef.on_rotate then -- Node provides a handler, so let the handler decide instead if the node can be rotated
		-- Copy pos and node because callback can modify it
		local result = ndef.on_rotate(vector.new(pos),
				{name = node.name, param1 = node.param1, param2 = node.param2},
				user, mode, new_param2)
		if result == false then -- Disallow rotation
			return
		elseif result == true then
			should_rotate = false
		end
	else
		if not ndef or not ndef.paramtype2 == "facedir" or
				(ndef.drawtype == "nodebox" and
				not ndef.node_box.type == "fixed") or
				node.param2 == nil then
			return
		end

		if ndef.can_dig and not ndef.can_dig(pos, user) then
			return
		end
	end

	if should_rotate then
		node.param2 = new_param2
		core.swap_node(pos, node)
	end

	if not core.setting_getbool("creative_mode") then
		itemstack:add_wear(65535 / (USES - 1))
	end

	return itemstack
end
