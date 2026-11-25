package icu.juzeppe.bridge;

import com.simibubi.create.content.logistics.stockTicker.StockTickerBlockEntity;
import com.simibubi.create.content.logistics.stockTicker.StockTickerInteractionHandler;
import dan200.computercraft.api.lua.IComputerSystem;
import dan200.computercraft.api.lua.ILuaAPI;
import dan200.computercraft.api.lua.LuaFunction;
import dan200.computercraft.shared.computer.menu.ComputerMenu;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.level.ChunkPos;

/** Opens the existing Create menu for exactly one real viewer of this terminal. */
public final class StockApi implements ILuaAPI {
    private static final ResourceLocation SHOPPING_LIST =
        ResourceLocation.fromNamespaceAndPath("create", "shopping_list");
    private final IComputerSystem computer;

    StockApi(IComputerSystem computer) {
        this.computer = computer;
    }

    @Override
    public String[] getNames() {
        return new String[]{"juzeppebridge"};
    }

    /** No coordinates, player names or commands are accepted from Lua. */
    @LuaFunction(mainThread = true)
    public final Object[] openStock() {
        var level = computer.getLevel();
        BlockPos position = computer.getPosition();
        ServerPlayer viewer = null;
        for (ServerPlayer candidate : level.players()) {
            if (!(candidate.containerMenu instanceof ComputerMenu menu)) continue;
            var viewed = menu.getComputer();
            if (viewed.getID() != computer.getID() || viewed.getLevel() != level ||
                !viewed.getPosition().equals(position)) continue;
            if (viewer != null) return fail("Only one player may use this terminal at a time");
            viewer = candidate;
        }
        if (viewer == null || viewer.isSpectator() || !viewer.containerMenu.stillValid(viewer)) {
            return fail("Open this computer's terminal in Minecraft first");
        }

        BlockPos target = Bindings.get(level).target(position);
        if (target == null) {
            for (Direction side : Direction.values()) {
                BlockPos adjacent = position.relative(side);
                if (!level.hasChunkAt(adjacent) ||
                    !(level.getBlockEntity(adjacent) instanceof StockTickerBlockEntity)) continue;
                if (target != null) return fail("Multiple tickers: ask an admin to bind one");
                target = adjacent;
            }
        }
        if (target == null) return fail("No ticker bound to this computer");
        if (!JuzeppeBridge.near(position, target)) return fail("Ticker is too far away");
        double x = target.getX() + 0.5;
        double y = target.getY() + 0.5;
        double z = target.getZ() + 0.5;
        if (viewer.distanceToSqr(x, y, z) > 32 * 32 ||
            !viewer.getChunkTrackingView().contains(new ChunkPos(target)) ||
            !level.hasChunkAt(target)) return fail("Ticker is outside the player's loaded area");
        if (!(level.getBlockEntity(target) instanceof StockTickerBlockEntity ticker) ||
            ticker.isRemoved()) return fail("Ticker is missing");
        if (!ticker.isKeeperPresent()) return fail("Place a Stock Keeper or Blaze Burner next to the ticker");
        if (!ticker.behaviour.mayInteract(viewer)) return fail("Create network is locked for this player");
        // Create's normal interaction treats a held shopping list as a purchase.
        // Do not let this menu-only operation accidentally execute that path.
        if (SHOPPING_LIST.equals(BuiltInRegistries.ITEM.getKey(viewer.getMainHandItem().getItem()))) {
            return fail("Put the shopping list away before opening the stock menu");
        }
        var previousMenu = viewer.containerMenu;
        boolean handled = StockTickerInteractionHandler.interactWithLogisticsManagerAt(viewer, level, target);
        if (!handled || previousMenu == viewer.containerMenu) return fail("Create could not open the stock menu");
        return new Object[]{true};
    }

    private static Object[] fail(String reason) {
        return new Object[]{false, reason};
    }
}
