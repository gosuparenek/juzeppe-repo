package icu.juzeppe.bridge;

import java.util.HashMap;
import java.util.Map;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.saveddata.SavedData;

/** One binding per physical terminal position in each dimension. */
final class Bindings extends SavedData {
    private static final Factory<Bindings> FACTORY =
        new Factory<>(Bindings::new, Bindings::load, null);
    private final Map<Long, Long> entries = new HashMap<>();

    static Bindings get(ServerLevel level) {
        return level.getDataStorage().computeIfAbsent(FACTORY, "juzeppe_bridge");
    }

    private static Bindings load(CompoundTag tag, HolderLookup.Provider registries) {
        Bindings result = new Bindings();
        CompoundTag data = tag.getCompound("bindings");
        for (String key : data.getAllKeys()) {
            try {
                result.entries.put(Long.parseLong(key), data.getLong(key));
            } catch (NumberFormatException ignored) {
                // Ignore an invalid entry instead of losing every other binding.
            }
        }
        return result;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        CompoundTag data = new CompoundTag();
        entries.forEach((key, value) -> data.putLong(Long.toString(key), value));
        tag.put("bindings", data);
        return tag;
    }

    BlockPos target(BlockPos computer) {
        Long value = entries.get(computer.asLong());
        return value == null ? null : BlockPos.of(value);
    }

    void bind(BlockPos computer, BlockPos ticker) {
        entries.put(computer.asLong(), ticker.asLong());
        setDirty();
    }

    boolean unbind(BlockPos computer) {
        if (entries.remove(computer.asLong()) == null) return false;
        setDirty();
        return true;
    }
}
