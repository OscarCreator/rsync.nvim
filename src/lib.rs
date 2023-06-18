use mlua::prelude::*;
use std::fs;
use toml::{self, Table};

// Return toml content as lua table. If err an empty table
#[no_mangle]
fn decode_toml(lua: &Lua, file_path: String) -> LuaResult<LuaTable> {
    let contents = fs::read_to_string(file_path)?;
    let toml = lua.create_table()?;
    if let Ok(table) = contents.parse::<Table>() {
        for (k, v) in table {
            let i = lua.to_value(&v)?;
            toml.raw_set(k, i)?;
        }
    }
    Ok(toml)
}

#[no_mangle]
#[mlua::lua_module]
fn rsync_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    exports.set("decode_toml", lua.create_function(decode_toml)?)?;
    Ok(exports)
}
