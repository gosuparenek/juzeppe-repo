package icu.juzeppe.bridge;

import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import com.simibubi.create.content.logistics.stockTicker.StockTickerBlockEntity;
import dan200.computercraft.api.ComputerCraftAPI;
import dan200.computercraft.shared.computer.blocks.AbstractComputerBlockEntity;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.arguments.coordinates.BlockPosArgument;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.neoforged.fml.common.Mod;
import net.neoforged.fml.event.lifecycle.FMLCommonSetupEvent;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.RegisterCommandsEvent;

@Mod("juzeppe_bridge")
public final class JuzeppeBridge {
    static final int MAX_DISTANCE = 24;

    public JuzeppeBridge(IEventBus modBus) {
        modBus.addListener(this::setup);
        NeoForge.EVENT_BUS.addListener(this::registerCommands);
    }

    private void setup(FMLCommonSetupEvent event) {
        event.enqueueWork(() -> ComputerCraftAPI.registerAPIFactory(StockApi::new));
    }

    private void registerCommands(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("juzeppebridge")
            .requires(source -> source.hasPermission(2))
            .then(Commands.literal("bind")
                .then(Commands.argument("computer", BlockPosArgument.blockPos())
                    .then(Commands.argument("ticker", BlockPosArgument.blockPos())
                        .executes(this::bind))))
            .then(Commands.literal("unbind")
                .then(Commands.argument("computer", BlockPosArgument.blockPos())
                    .executes(this::unbind))));
    }

    private int bind(CommandContext<CommandSourceStack> context) throws CommandSyntaxException {
        var source = context.getSource();
        var level = source.getLevel();
        BlockPos computer = BlockPosArgument.getLoadedBlockPos(context, "computer");
        BlockPos ticker = BlockPosArgument.getLoadedBlockPos(context, "ticker");
        if (!(level.getBlockEntity(computer) instanceof AbstractComputerBlockEntity)) {
            source.sendFailure(Component.literal("No CC computer at the first position."));
            return 0;
        }
        if (!(level.getBlockEntity(ticker) instanceof StockTickerBlockEntity)) {
            source.sendFailure(Component.literal("No Create Stock Ticker at the second position."));
            return 0;
        }
        if (!near(computer, ticker)) {
            source.sendFailure(Component.literal("Ticker must be within 24 blocks of the computer."));
            return 0;
        }
        Bindings.get(level).bind(computer, ticker);
        source.sendSuccess(() -> Component.literal("Juzeppe Bridge: terminal bound to " + ticker.toShortString()), true);
        return 1;
    }

    private int unbind(CommandContext<CommandSourceStack> context) throws CommandSyntaxException {
        var source = context.getSource();
        BlockPos computer = BlockPosArgument.getLoadedBlockPos(context, "computer");
        if (!Bindings.get(source.getLevel()).unbind(computer)) {
            source.sendFailure(Component.literal("No binding at that position."));
            return 0;
        }
        source.sendSuccess(() -> Component.literal("Juzeppe Bridge: terminal unbound."), true);
        return 1;
    }

    static boolean near(BlockPos computer, BlockPos ticker) {
        return computer.distSqr(ticker) <= MAX_DISTANCE * MAX_DISTANCE;
    }
}
