package icu.juzeppe.bridge;

import com.simibubi.create.content.logistics.stockTicker.StockTickerBlockEntity;
import com.simibubi.create.content.logistics.stockTicker.StockTickerInteractionHandler;
import dan200.computercraft.api.lua.IComputerSystem;
import dan200.computercraft.api.lua.ILuaAPI;
import dan200.computercraft.api.lua.LuaFunction;
import dan200.computercraft.shared.computer.menu.ComputerMenu;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import dan200.computercraft.shared.computer.blocks.AbstractComputerBlockEntity;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.level.ChunkPos;

/** Opens the existing Create menu for exactly one real viewer of this terminal. */
public final class StockApi implements ILuaAPI {
    private static final ResourceLocation SHOPPING_LIST =
        ResourceLocation.fromNamespaceAndPath("create", "shopping_list");
    // Main-thread only, short-lived and bound to the requesting CC computer.
    private record Ticket(ServerLevel level, BlockPos host, int hostId, BlockPos ticker,
                          int clientId, long expires) {}
    private static final Map<String, Ticket> TICKETS = new HashMap<>();
    private final IComputerSystem computer;

    StockApi(IComputerSystem computer) {
        this.computer = computer;
    }

    @Override
    public String[] getNames() {
        return new String[]{"juzeppebridge"};
    }

    @LuaFunction(mainThread = true)
    public final Object[] offerNative(int clientId) {
        var level = computer.getLevel();
        var host = computer.getPosition();
        if (clientId < 0 || !(level.getBlockEntity(host) instanceof AbstractComputerBlockEntity block) ||
            block.getComputerID() != computer.getID()) return new Object[]{null, "Invalid stock host"};
        BlockPos ticker = null;
        for (Direction side : Direction.values()) {
            BlockPos adjacent = host.relative(side);
            if (!level.hasChunkAt(adjacent) ||
                !(level.getBlockEntity(adjacent) instanceof StockTickerBlockEntity)) continue;
            if (ticker != null) return new Object[]{null, "Multiple adjacent tickers"};
            ticker = adjacent;
        }
        if (ticker == null) return new Object[]{null, "Stock Host needs an adjacent ticker"};
        long now = System.currentTimeMillis();
        TICKETS.entrySet().removeIf(entry -> entry.getValue().expires() <= now);
        if (TICKETS.size() >= 1024) return new Object[]{null, "Stock service busy"};
        String token = UUID.randomUUID().toString();
        TICKETS.put(token, new Ticket(level, host.immutable(), computer.getID(), ticker.immutable(), clientId, now + 15000));
        return new Object[]{token};
    }

    @LuaFunction(mainThread = true)
    public final Object[] openRemote(String token) {
        Ticket ticket = TICKETS.get(token);
        var level = computer.getLevel();
        if (ticket == null || ticket.expires() <= System.currentTimeMillis() ||
            ticket.level() != level || ticket.clientId() != computer.getID()) {
            return fail("Wireless stock invitation expired or invalid");
        }
        TICKETS.remove(token);
        if (!level.hasChunkAt(ticket.host()) ||
            !(level.getBlockEntity(ticket.host()) instanceof AbstractComputerBlockEntity host) ||
            host.getComputerID() != ticket.hostId()) return fail("Stock Host disconnected");
        return open(ticket.ticker(), true);
    }

    /** No coordinates, player names or commands are accepted from Lua. */
    @LuaFunction(mainThread = true)
    public final Object[] openStock() {
        return open(null, false);
    }

    private Object[] open(BlockPos remote, boolean wireless) {
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

        BlockPos target = wireless ? remote : Bindings.get(level).target(position);
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
        if (!viewer.getChunkTrackingView().contains(new ChunkPos(target)) ||
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
        // Create itself validates order distance. Warn before handing off to its menu.
        if (!target.closerThan(viewer.blockPosition(), 20)) {
            viewer.sendSystemMessage(Component.literal(
                "Juzeppe Bridge: this ticker is far away. Create may reject orders; use a closer ticker to order."));
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
